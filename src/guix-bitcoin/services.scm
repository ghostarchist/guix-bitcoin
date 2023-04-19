(define-module (guix-bitcoin services)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)

  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix records)

  #:use-module (guix-bitcoin packages))
