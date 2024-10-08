##  pkgKitten -- A saner way to create packages to build upon
##
##  Copyright (C) 2014 - 2024  Dirk Eddelbuettel <edd@debian.org>
##
##  This file is part of pkgKitten
##
##  pkgKitten is free software: you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation, either version 2 of the License, or
##  (at your option) any later version.
##
##  pkgKitten is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with pkgKitten.  If not, see <http://www.gnu.org/licenses/>.


##' The \code{kitten} function creates an (almost) empty example
##' package.
##'
##' The \code{kitten} function can be used to initialize a simple
##' package.  It is created with the minimal number of files. What
##' distinguished it from the function \code{package.skeleton()} in
##' base R (which it actually calls) is that the resulting package
##' passes \code{R CMD check cleanly}.
##'
##' Because every time you create a new package which does \emph{not}
##' pass \code{R CMD check}, a kitten experiences an existential
##' trauma. Just think about the kittens.
##' @title Create a very simple package
##' @param name The name of the package to be created, defaults to \dQuote{anRpackage}
##' @param path The path to the location where the package is to be
##' created, defaults to the current directory.
##' @param author The name of the author, defaults to the result of
##' \code{\link[whoami]{fullname}} (or \dQuote{Your Name} as fallback).
##' @param maintainer The name of the maintainer, also defaults to
##' \code{\link[whoami]{fullname}} or \code{author} if the latter is given.
##' @param email The maintainer email address, defaults to
##' \code{\link[whoami]{email_address}} (or \dQuote{your@email.com} as fallback).
##' @param license The license of the new package, defaults to \dQuote{GPL-2}.
##' @param puppy Toggle whether \code{tinytest::puppy} add unit testing, default
##' to true (but conditional on \code{tinytest} being installed).
##' @param bunny Toggle whether \code{roxygen2} should be used for the
##' the creation of Rd files from R, default is true (but also conditional on
##' \code{roxygen2} being install).
##' @return Nothing is returned as the function is invoked for its
##' side effect of creating a new package.
##' @author Dirk Eddelbuettel
kitten <- function(name = "anRpackage",
                   path = ".",
                   author,                         # or from 'whoami' if missing
                   maintainer,                     # or from 'whoami' if missing
                   email, # = email_address(),     # or from 'whomai' if missing
                   license = "GPL (>= 2)", 	   # default choice
                   puppy = TRUE,                   # default choice add tinytest
                   bunny = TRUE) {                 # default choice add roxygen2

    haswhoami <- requireNamespace("whoami", quietly=TRUE)
    hasroxygen <- requireNamespace("roxygen2", quietly=TRUE)
    if (missing(author))
        author <- if (haswhoami) whoami::fullname("Your Name") else "Your Name"
    if (missing(maintainer))
        maintainer <- author
    if (missing(email))
        email <- if (haswhoami) whoami::email_address("your@email.com") else "your@email.com"

    call <- match.call()                	# how were we called
    call[[1]] <- as.name("package.skeleton")    # run as if package.skeleton() was called
    env <- parent.frame(1)                      # access to what is in the environment

    if (file.exists(file.path(path, name))) {
        stop("Directory '", name, "' already exists. Aborting.", call.=FALSE)
    }

    assign("kitten.fake.fun", function() {}, envir = env)

    call <- call[ c(1L, which(names(call) %in% names(formals(package.skeleton)))) ]
    call[["list"]] <- "kitten.fake.fun"

    tryCatch(eval(call, envir = env), error = function(e){
        stop(sprintf("error while calling `package.skeleton` : %s", conditionMessage(e)))
    })

    message("\nAdding pkgKitten overrides.")

    root <- file.path(path, name)    ## now pick things up from here
    DESCRIPTION <- file.path(root, "DESCRIPTION")
    if (file.exists(DESCRIPTION)) {
        x <- read.dcf(DESCRIPTION, fields = c("Package", "Type", "Title", "Version", "Date",
                                              "Description", "License"))

        ## add 'Authors@R'
        x <- cbind(x, matrix("person", 1, 1, dimnames=list("", "Authors@R")))
        splitname <- strsplit(author, " ")[[1]]
        x[1, "Authors@R"] <- sprintf(r"(person("%s", "%s", role = c("aut", "cre"), email = "%s"))",
                                    paste(splitname[-length(splitname)], collapse=" "),
                                    splitname[length(splitname)],
                                    email)

        x[, "License"] <- license
        x[, "Title"] <- "Concise Summary of What the Package Does"
        x[, "Description"] <- "More about what it does (maybe more than one line)."

        write.dcf(x[1, c("Package", "Type", "Title", "Version", "Date",
                         "Authors@R", "Description", "License"),
                    drop = FALSE],
                  file = DESCRIPTION)
    }

    dotgitignore <- system.file("skel", "R.gitignore", package="pkgKitten")
    tgtgitignore <- file.path(root, ".gitignore")
    if (!file.exists(tgtgitignore)) {
        file.copy(dotgitignore, tgtgitignore, overwrite=TRUE)
        message(" >> added .gitignore file")
    }

    dotRbuildignore <- system.file("skel", "dot.Rbuildignore", package="pkgKitten")
    tgtRbuildignore <- file.path(root, ".Rbuildignore")
    if (! file.exists(tgtRbuildignore)) {
        file.copy(dotRbuildignore, tgtRbuildignore, overwrite=TRUE)
        message(" >> added .Rbuildignore file")
    }

    playWithPerPackageHelpPage(name, path, maintainer, email)

    rtgt <- file.path(root, "R", "hello.R")
    rsrc <- system.file("replacements", "hello.R", package="pkgKitten")
    file.copy(rsrc, rtgt, overwrite=TRUE)

    rdtgt <- file.path(root, "man", "hello.Rd")
    rdsrc <- system.file("replacements", "hello.Rd", package="pkgKitten")
    file.copy(rdsrc, rdtgt, overwrite=TRUE)

    rm("kitten.fake.fun", envir = env)
    unlink(file.path(root, "R"  , "kitten.fake.fun.R"))
    unlink(file.path(root, "man", "kitten.fake.fun.Rd"))

    rdtgt <- file.path(root, "NAMESPACE")
    rdsrc <- system.file("replacements", "NAMESPACE", package="pkgKitten")
    file.copy(rdsrc, rdtgt, overwrite=TRUE)

    if (puppy && requireNamespace("tinytest", quietly=TRUE)) {
        tinytest::setup_tinytest(root, verbose=FALSE)
        tinytgt <- file.path(root, "inst", "tinytest",
                             paste0("test_", name, ".R"))
        tinysrc <- system.file("replacements", "test_hello.R",
                               package="pkgKitten")
        file.copy(tinysrc, tinytgt, overwrite=TRUE)
        message(" >> added tinytest support")
    }

    if (hasroxygen && bunny) {
        rtgt <- file.path(root, "R", "hello2.R")
        rsrc <- system.file("replacements", "hello2.R", package="pkgKitten")
        file.copy(rsrc, rtgt, overwrite=TRUE)
        cwd <- getwd()
        setwd(root)
        cat("Encoding: UTF-8\n", file="DESCRIPTION", append=TRUE)
        roxygen2::roxygenize(".")
        setwd(cwd)
    }

    unlink(file.path(root, "Read-and-delete-me"))
    message("Deleted 'Read-and-delete-me'.")
    message("Done.\n")

    message("Consider reading the documentation for all the packaging details.")
    message("A good start is the 'Writing R Extensions' manual.\n")

    message("And run 'R CMD check'. Run it frequently. And think of those kittens.\n")

    invisible(NULL)
}

##' The \code{playWithPerPackageHelpPage} function creates an basic
##' package help page.
##'
##' The \code{playWithPerPackageHelpPage} function can be used to
##' create a simple help page for a package.
##'
##' It has been split off from the \code{kitten} function so that it
##' can be called from other packages. As such, it is also exported
##' from \pkg{pkgKitten}.
##'
##' @title Create a very simple package help page
##' @param name The name of the package to be created, defaults to \dQuote{anRpackage}
##' @param path The path to the location where the package is to be
##' created, defaults to the current directory.
##' @param maintainer The name of the maintainer, defaults to
##' \dQuote{Your Name} or \code{author} if the latter is given.
##' @param email The maintainer email address.
##' @return Nothing is returned as the function is invoked for its
##' side effect of creating a new package.
##' @author Dirk Eddelbuettel
playWithPerPackageHelpPage <- function(name = "anRpackage",
                                       path = ".",
                                       maintainer = "Your Name",
                                       email = "your@mail.com") {
    root <- file.path(path, name)
    helptgt <- file.path(root, "man", sprintf( "%s-package.Rd", name))
    helpsrc <- system.file("replacements", "manual-page-stub.Rd", package="pkgKitten")
    ## update the package description help page
    if (file.exists(helpsrc)) {
        lines <- readLines(helpsrc)
        lines <- gsub("__placeholder__", name, lines, fixed = TRUE)
        lines <- gsub("Who to complain to <yourfault@somewhere.net>",
                      sprintf( "%s <%s>", maintainer, email),
                      lines, fixed = TRUE)
        writeLines(lines, helptgt)
    }
    invisible(NULL)
}
