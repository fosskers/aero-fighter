(require :asdf)

;; Force ASDF to only look here for systems.
(asdf:initialize-source-registry `(:source-registry (:tree ,(uiop:getcwd)) :ignore-inherited-configuration))

#+ecl
(progn
  (let* ((path (merge-pathnames "lib/" (ext:getcwd)))
         (args (format nil "-Wl,-rpath,~a -L~a" path path)))
    (setf c:*user-linker-flags* args)
    (setf c:*user-linker-libs*  "-llisp-raylib -llisp-raylib-shim"))
  (declaim (optimize (speed 3) (debug 1) (safety 1))))

(format t "--- DETECTING ENVIRONMENT ---~%")
(let ((mode (or #+sbcl (sb-ext:posix-getenv "CL_MODE")
                #+ecl (ext:getenv "CL_MODE")
                "DEV")))
  (when (string-equal "RELEASE" mode)
    (format t "--> RELEASE MODE DETECTED~%")
    (pushnew :release *features*)))

(format t "--- LOADING SYSTEM ---~%")
;; NOTE: 2025-02-07 The `:force' is to ensure that an ECL-based build properly
;; compiles and loads all its files. This is critical to ensure that no C-level
;; symbols are missing, say from shared objects.
(asdf:load-system :raylib :force t)
(asdf:load-system :aero-slicer :force t)

#+ecl
(progn
  (format t "--- ECL: COMPILING EXECUTABLE ---~%")
  (asdf:make-build :aero-slicer
                   :type :program
                   :move-here #p"./"
                   :epilogue-code
                   '(progn
                     (aero-slicer:launch)
                     (ext:quit)))
  (ext:quit))

#+sbcl
(progn
  (format t "--- SBCL: SAVING IMAGE ---~%")
  (format t "POLICY: ~a~%" sb-c::*policy*)
  (let ((bin (or #+win32 #p"aero-slicer.exe"
                 #p"aero-slicer")))
    (sb-ext:save-lisp-and-die bin
                              :toplevel #'aero-slicer:launch
                              :executable t
                              :compression (if (member :sb-core-compression *features*) t))))
