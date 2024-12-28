(defpackage raylib
  (:use :cl :sb-alien)
  (:local-nicknames (#:tg #:trivial-garbage)))

(in-package :raylib)

;; TODO: 2024-12-25 Probably need an `eval-when' here.
(load-shared-object #p"/home/colin/code/common-lisp/aero-fighter/vendored/raylib/src/libraylib.so")
(load-shared-object #p"/home/colin/code/common-lisp/aero-fighter/c/shim.so")

#++
(progn
  (unload-shared-object #p"/home/colin/code/common-lisp/aero-fighter/vendored/raylib/src/libraylib.so")
  (load-shared-object #p"/home/colin/code/common-lisp/aero-fighter/vendored/raylib/src/libraylib.so"))

#++
(progn
  (unload-shared-object #p"/home/colin/code/common-lisp/aero-fighter/c/shim.so")
  (load-shared-object #p"/home/colin/code/common-lisp/aero-fighter/c/shim.so"))

;; --- Vectors --- ;;

(define-alien-type nil
    (struct vector2-raw
            (x float)
            (y float)))

(define-alien-routine ("_MakeVector2" make-vector2-raw) (* (struct vector2-raw))
  (x float)
  (y float))

(defstruct (vector2 (:constructor @vector2))
  (pointer nil :type alien))

(defun make-vector2 (&key x y)
  (let* ((ptr (make-vector2-raw x y))
         (v   (@vector2 :pointer ptr)))
    (tg:finalize v (lambda () (free-alien ptr)))))

(defmacro vector2-x (v)
  "The X slot of a `Vector2'."
  `(sb-alien:slot (vector2-pointer ,v) 'x))

(defmacro vector2-y (v)
  "The Y slot of a `Vector2'."
  `(sb-alien:slot (vector2-pointer ,v) 'y))

#++
(let ((v (make-vector2 :x 1.0 :y 2.0)))
  (setf (vector2-x v) 1000.0)
  (vector2-x v))

#++
(tg:gc :full t :verbose t)

;; --- Colour --- ;;

(define-alien-type nil
    (struct color-raw
            (r unsigned-char)
            (g unsigned-char)
            (b unsigned-char)
            (a unsigned-char)))

(define-alien-routine ("_MakeColor" make-color-raw) (* (struct color-raw))
  (r unsigned-char)
  (g unsigned-char)
  (b unsigned-char)
  (a unsigned-char))

(defstruct (color (:constructor @color))
  (pointer nil :type alien))

(defun make-color (&key r g b a)
  (let* ((pointer (make-color-raw r g b a))
         (color   (@color :pointer pointer)))
    (tg:finalize color (lambda () (free-alien pointer)))))

;; --- Textures --- ;;

(define-alien-type nil
    (struct texture-2d-raw
            (id unsigned-int)
            (width int)
            (height int)
            (mipmaps int)
            (format int)))

(defstruct (texture-2d (:constructor @texture-2d))
  (pointer nil :type alien))

(define-alien-routine ("_LoadTexture" load-texture-raw) (* (struct texture-2d-raw))
  (file-name c-string))

(defun load-texture (file-name)
  (let* ((pointer (load-texture-raw file-name))
         (texture (@texture-2d :pointer pointer)))
    (tg:finalize texture (lambda () (free-alien pointer)))))

#++
(progn
  (init-window 300 300 "hello!")
  (let ((p (load-texture-raw "assets/logo.png")))
    (format t "~a~%" (slot p 'id))
    (format t "~a~%" (slot p 'width))
    (format t "~a~%" (slot p 'height)))
  (close-window))

;; --- Window --- ;;

(define-alien-routine ("InitWindow" init-window) void
  (width int)
  (height int)
  (title c-string))

(define-alien-routine ("CloseWindow" close-window) void)

(define-alien-routine ("SetTargetFPS" set-target-fps) void
  (fps int))

(define-alien-routine ("WindowShouldClose" window-should-close) boolean)

(define-alien-routine ("BeginDrawing" begin-drawing) void)

(define-alien-routine ("EndDrawing" end-drawing) void)

(define-alien-routine ("DrawFPS" draw-fps) void
  (pos-x int)
  (pos-y int))

(define-alien-routine ("_ClearBackground" clear-background-raw) void
  (color (* (struct color-raw))))

(defun clear-background (color)
  (clear-background-raw (color-pointer color)))

#++
(progn
  (let ((colour (make-color :r 255 :g 255 :b 255 :a 255)))
    (init-window 300 300 "hello!")
    (set-target-fps 60)
    (loop while (not (window-should-close))
          do (progn (begin-drawing)
                    (clear-background colour)
                    (draw-fps 0 0)
                    (end-drawing)))
    (close-window)))