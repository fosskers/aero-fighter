(require :asdf)

;; Force ASDF to only look here for systems.
(asdf:initialize-source-registry `(:source-registry (:tree ,(uiop:getcwd)) :ignore-inherited-configuration))

;; Load and compile the binary.
(format t "--- LOADING SYSTEM ---~%")
(asdf:load-system :aero-fighter)
(format t "--- COMPILING EXECUTABLE ---~%")

#+ecl
(progn
  (setf c:*user-linker-flags* "-Wl,-rpath,/home/colin/code/common-lisp/aero-fighter/lib/ -L/home/colin/code/common-lisp/aero-fighter/lib/")
  (setf c:*user-linker-libs*  "-lraylib -lshim")
  (asdf:make-build :aero-fighter
                   :type :program
                   :move-here #p"./"
                   :epilogue-code
                   '(progn
                     (aero-fighter:launch)
                     (si:exit))))

#+sbcl
(progn
  (format t "POLICY: ~a~%" sb-c::*policy*)
  (sb-ext:save-lisp-and-die #p"aero-fighter"
                            :toplevel #'aero-fighter:launch
                            :executable t
                            :compression t))

(format t "--- DONE ---~%")

#+ecl
(si:exit)
