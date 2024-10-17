(defsystem claw-raylib.defcfun
  :version "1.0.0"
  :author "Bohong Huang <1281299809@qq.com>"
  :maintainer "Bohong Huang <1281299809@qq.com>"
  :license "Apache-2.0"
  :homepage "https://github.com/bohonghuang/claw-raylib"
  :bug-tracker "https://github.com/bohonghuang/claw-raylib/issues"
  :source-control (:git "https://github.com/bohonghuang/claw-raylib.git")
  :defsystem-depends-on (:trivial-features)
  :depends-on (#:alexandria #:cffi #:cffi-ops #:cffi-object #:cffi-object.ops)
  :components ((:file "defcfun")))
