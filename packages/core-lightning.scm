(define-module (packages lightning)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system emacs)
  #:use-module (guix build-system haskell)
  #:use-module (guix build-system python)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system glib-or-gtk)
  #:use-module (guix build-system go)
  #:use-module (guix build-system qt)
  #:use-module (guix deprecation)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (srfi srfi-26)
  #:use-module (gnu packages)
  #:use-module (gnu packages aidc)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages docbook)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages dns)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages emacs-xyz)
  #:use-module (gnu packages dbm)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages groff)
  #:use-module (gnu packages gsasl)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages haskell-check)
  #:use-module (gnu packages haskell-web)
  #:use-module (gnu packages haskell-xyz)
  #:use-module (gnu packages jemalloc)
  #:use-module (gnu packages libedit)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages libunwind)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages man)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages mpi)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages networking)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages popt)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages sphinx)
  #:use-module (gnu packages tex)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages time)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages upnp)
  #:use-module (gnu packages web)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages gnuzilla))

(define-public c-lightning
  (package
    (name "c-lightning")
    (version "0.9.3")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/ElementsProject/lightning/releases/download/"
               "v" version "/clightning-v" version ".zip"))
        (sha256
          (base32 "1chqzxcqpr49vbayrw4213lznmyw4lcghcdh6afxbk4bxlhkjmml"))))
    (build-system gnu-build-system)
    (native-inputs
      `(("autoconf" ,autoconf)
        ("automake" ,automake)
        ("bash" ,bash)
        ("libtool" ,libtool)
        ("pkg-config" ,pkg-config)
        ("python" ,python)
        ("python-mako" ,python-mako)
        ("sed" ,sed)
        ("unzip" ,unzip)
        ("which" ,which)))
    (inputs
      `(("gmp" ,gmp)
        ("sqlite" ,sqlite)
        ("zlib" ,zlib)))
    (arguments
      ;; Tests exist, but need a lot of Python packages (some not available
      ;; on Guix) and they are incompatible with our BINTOPKGLIBEXECDIR hack.
      `(#:tests? #f
        #:phases
        (modify-phases %standard-phases
          (add-before 'configure 'patch-makefile
            (lambda _
              (substitute* "Makefile"
                ;; The C-lightning Makefile uses the PYTHONPATH
                ;; variable, which causes Guix builds to fail
                ;; since the environment variable is masked by
                ;; the Makefile variable.
                ;; Insert the contents of the variable into the
                ;; Makefile.
                (("^PYTHONPATH=")
                 (string-append
                   "PYTHONPATH="
                   (getenv "PYTHONPATH")
                   ":"))
                ;; C-lightning will spawn a number of other
                ;; processes from binaries installed in its
                ;; libexecdir.
                ;; It normally uses relative paths so that
                ;; users can move around the installation
                ;; location.
                ;; However, it does have the drawback that if
                ;; the installation location is overwritten
                ;; with a newer version while an existing
                ;; instance is still running, any new
                ;; sub-processes launched will be the new
                ;; version, which is likely incompatible with
                ;; the running instance.
                ;; Since Guix would not allow the store
                ;; directory to be moved anyway, we use an
                ;; absolute path instead in the below
                ;; substitution.
                ;; With Guix and an absolute path, even if a
                ;; running instance was launched from a
                ;; profile and that profile is upgraded to a
                ;; newer version, the running instance will
                ;; refer to the absolute store directory
                ;; containing binaries of the running version.
                (("BINTOPKGLIBEXECDIR=.*$")
                 "BINTOPKGLIBEXECDIR='\"'\"$(pkglibexecdir)\"'\"'\n"))))
          ;; C-lightning configure is unusual, it does not understand
          ;; the standard parameters Guix passes in, so, provide those
          ;; by env variables.
          (replace 'configure
            (lambda* (#:key outputs inputs (configure-flags '())
                      #:allow-other-keys)
              (let* ((bash    (string-append (assoc-ref inputs "bash") "/bin/bash"))
                     (python  (assoc-ref inputs "python"))
                     (prefix  (assoc-ref outputs "out"))
                     (flags   (cons*
                                "CC=gcc"
                                (string-append "--prefix=" prefix)
                                configure-flags)))
                (setenv "PYTHON" (string-append python "/bin/python3"))
                (setenv "CONFIG_SHELL" bash)
                (setenv "SHELL" bash)
                (format #t "build directory: ~s~%" (getcwd))
                (format #t "configure flags: ~s~%" flags)
                (apply invoke bash
                       "./configure"
                       flags))))
          ;; Rather than call the configure script of its external
          ;; libraries from its own configure script, the external
          ;; configure are created and called at build time.
          ;; Unfortunately, it is a single Makefile stanza which
          ;; does the autoreconf, configure, and make.
          ;; This means we cannot "cut" through here by creating
          ;; the external configure before this step (the Makefile
          ;; stanza will recreate and overwrite the external
          ;; configure), we have to modify the autogen.sh scripts
          ;; of the external libraries instead so that they
          ;; patch the shebangs after autoreconf.
          (add-before 'build 'fix-autoreconf
            (lambda _
              (substitute* "external/libsodium/autogen.sh"
                (("exec autoreconf(.*)$" exec-autoreconf flags)
                 (string-append
                   "autoreconf" flags
                   "sed 's:/bin/sh:" (getenv "SHELL") ":g' < configure > configure.tmp\n"
                   "mv configure.tmp configure\n"
                   "chmod +x configure\n"
                   "exit 0\n")))
              (substitute* "external/libwally-core/tools/autogen.sh"
                (("autoreconf(.*)$" autoreconf)
                 (string-append
                   autoreconf
                   "sed 's:/bin/sh:" (getenv "SHELL") ":g' < configure > configure.tmp\n"
                   "mv configure.tmp configure\n"
                   "chmod +x configure\n"))))))))
    (home-page "https://github.com/ElementsProject/lightning")
    (synopsis "Lightweight Lightning Network protocol implementation in C")
    (description
      "c-lightning is a lightweight, highly customizable, and standard
compliant implementation of the Lightning Network protocol.")
    (license license:expat)))

(define-public c-lightning-postgresql
  (package
    (inherit c-lightning)
    (name "c-lightning-postgresql")
    (inputs
      `(("postgresql" ,postgresql)
        ;; C-Lightning requires SQLITE3 as of 0.9.3, and will
        ;; fail to build if it is not found.
        ;; (The configure script will allow PostgreSQL without
        ;; SQLITE3 but some build tool of C-Lightning fails if
        ;; SQLITE3 is not found.)
        ,@(package-inputs c-lightning)))
    (description
      "c-lightning is a lightweight, highly customizable, and standard
compliant implementation of the Lightning Network protocol.

This package includes support for using a PostgreSQL database to back
your node; you will need to set up the PostgreSQL separately and pass
in its details using an appropriate flag setting.")))
