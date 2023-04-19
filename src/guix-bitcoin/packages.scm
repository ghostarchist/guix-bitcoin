(define-module (guix-bitcoin packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system emacs)
  #:use-module (guix build-system python)
  #:use-module (guix deprecation)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (srfi srfi-26)
  #:use-module (gnu packages)
  #:use-module (gnu packages aidc)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages dbm)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages upnp)
  #:use-module (gnu packages finance))

(define-public bitcoin-core-latest
  (package
    (name "bitcoin-core-latest")
    (version "24.0.1")
    (source (origin
              (method url-fetch)
              (uri
               (string-append "https://bitcoincore.org/bin/bitcoin-core-"
                              version "/bitcoin-" version ".tar.gz"))
              (sha256
               (base32
                "1zzjymh5byah8qklzbag25z9jwiws5b7wc3k1m37sxmlz9nsvm0j"))))
    (build-system gnu-build-system)
    (native-inputs
     (list autoconf
           automake
           libtool
           pkg-config
           python ; for the tests
           util-linux ; provides the hexdump command for tests
           qttools-5))
    (inputs
     (list bdb-4.8 ; 4.8 required for compatibility
           boost
           libevent
           miniupnpc
           openssl
           qtbase-5))
    (arguments
     `(#:configure-flags
       (list
        ;; Boost is not found unless specified manually.
        (string-append "--with-boost="
                       (assoc-ref %build-inputs "boost"))
        ;; XXX: The configure script looks up Qt paths by
        ;; `pkg-config --variable=host_bins Qt5Core`, which fails to pick
        ;; up executables residing in 'qttools-5', so we specify them here.
        (string-append "ac_cv_path_LRELEASE="
                       (assoc-ref %build-inputs "qttools")
                       "/bin/lrelease")
        (string-append "ac_cv_path_LUPDATE="
                       (assoc-ref %build-inputs "qttools")
                       "/bin/lupdate"))
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'make-qt-deterministic
           (lambda _
             ;; Make Qt deterministic.
             (setenv "QT_RCC_SOURCE_DATE_OVERRIDE" "1")
             #t))
         (add-before 'build 'set-no-git-flag
           (lambda _
             ;; Make it clear we are not building from within a git repository
             ;; (and thus no information regarding this build is available
             ;; from git).
             (setenv "BITCOIN_GENBUILD_NO_GIT" "1")
             #t))
         (add-before 'check 'set-home
           (lambda _
             (setenv "HOME" (getenv "TMPDIR")) ; tests write to $HOME
             #t))
         (add-after 'check 'check-functional
           (lambda _
             (invoke
              "python3" "./test/functional/test_runner.py"
              (string-append "--jobs=" (number->string (parallel-job-count))))
             #t)))))
    (home-page "https://bitcoin.org/")
    (synopsis "Bitcoin peer-to-peer client")
    (description
     "Bitcoin is a digital currency that enables instant payments to anyone
anywhere in the world.  It uses peer-to-peer technology to operate without
central authority: managing transactions and issuing money are carried out
collectively by the network.  Bitcoin Core is the reference implementation
of the bitcoin protocol.  This package provides the Bitcoin Core command
line client and a client based on Qt.")
    (license license:expat)))

;; The support lifetimes for bitcoin-core versions can be found in
;; <https://bitcoincore.org/en/lifecycle/#schedule>.

(define-public electrum-latest
  (package
    (name "electrum-latest")
    (version "4.3.4")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://download.electrum.org/"
                           version "/Electrum-"
                           version ".tar.gz"))
       (sha256
        (base32 "06iviqcnarznvxj3agrmwl7jh407hxbk5bhhkdx5777fmxj0v7pr"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; Delete the bundled dependencies.
           (delete-file-recursively "packages")
           #t))))
    (build-system python-build-system)
    (inputs
     (list libsecp256k1
           python-aiohttp
           python-aiohttp-socks
           python-aiorpcx
           python-attrs
           python-bitstring
           python-btchip-python
           python-certifi
           python-cryptography
           python-dnspython
           python-hidapi
           python-ledgerblue
           python-protobuf
           python-pyqt
           python-qdarkstyle
           python-qrcode
           zbar))
    (arguments
     `(#:tests? #f                      ; no tests
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-prefix
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               ;; setup.py installs to ~/.local/share if sys.prefix/share isn't
               ;; writable.  sys.prefix points to Python's, not our, --prefix.
               (mkdir-p (string-append out "/share"))
               (substitute* "setup.py"
                 (("sys\\.prefix")
                  (format #f "\"~a\"" out)))
               #t)))
         (add-after 'unpack 'relax-dnspython-version-requirement
           ;; The version requirement for dnspython>=2.0,<2.1 makes the
           ;; sanity-check phase fail, but the application seems to be working
           ;; fine with dnspython 2.1 (the version we have currently).
           (lambda _
             (substitute* "contrib/requirements/requirements.txt"
               (("dnspython>=.*")
                "dnspython"))))
         (add-after 'unpack 'use-libsecp256k1-input
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* "electrum/ecc_fast.py"
               (("library_paths = .* 'libsecp256k1.so.0'.")
                (string-append "library_paths = ('"
                               (assoc-ref inputs "libsecp256k1")
                               "/lib/libsecp256k1.so.0'"))))))))
    (home-page "https://electrum.org/")
    (synopsis "Bitcoin wallet")
    (description
     "Electrum is a lightweight Bitcoin client, based on a client-server
protocol.  It supports Simple Payment Verification (SPV) and deterministic key
generation from a seed.  Your secret keys are encrypted and are never sent to
other machines/servers.  Electrum does not download the Bitcoin blockchain.")
    (license license:expat)))

