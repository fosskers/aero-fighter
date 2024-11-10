;;; Everything involving the fighter and his beam weapon.
;;;
;;; The beam weapon comes in three strengths, represented by beam width. The
;;; initial beam is 4 pixels wide. The next is 8, and the final is 16, the full
;;; width of the ship.

(in-package :aero-fighter)

#+nil
(launch)

;; --- Types --- ;;

(defstruct fighter
  "The player's fighter ship."
  (animated  nil :type animated)
  (pos       nil :type raylib:vector2)
  (bbox      nil :type raylib:rectangle)
  ;; Ok / Hit
  (status    'ok :type symbol)
  (status-fc 0   :type fixnum)
  ;; The next movement should be a warp.
  (warp-next? nil :type symbol)
  ;; The last time that the player did "warp movement".
  (warp-fc   0   :type fixnum)
  (beam      nil :type beam)
  (bombs     3   :type fixnum)
  ;; The last time a bomb was used.
  (bomb-fc   0   :type fixnum))

(defun fighter (fighter-sprite beam-sprite)
  "A smart-constructor for `fighter'."
  (let* ((animated (make-animated :sprite fighter-sprite))
         (rect     (bounding-box animated))
         (pos      (raylib:make-vector2 :x +fighter-spawn-x+
                                        :y +fighter-spawn-y+)))
    (make-fighter :animated animated
                  :pos pos
                  :bbox (raylib:make-rectangle :x +fighter-spawn-x+
                                               :y +fighter-spawn-y+
                                               :width (raylib:rectangle-width rect)
                                               :height (raylib:rectangle-height rect))
                  :beam (beam beam-sprite pos))))

;; --- Status --- ;;

(defun can-warp? (fighter fc)
  "Could the fighter warp on this frame?"
  (> (- fc (fighter-warp-fc fighter))
     +warp-cooldown+))

(defun can-bomb? (fighter fc)
  "Could the fighter launch a bomb on this frame?"
  (and (> (fighter-bombs fighter) 0)
       (> (- fc (fighter-bomb-fc fighter))
          +bomb-cooldown+)))

(defun kill-fighter! (fighter fc)
  "Reset the fighter's position and animation."
  (setf (fighter-status fighter) 'hit)
  (setf (fighter-status-fc fighter) fc)
  (setf (animated-active (fighter-animated fighter)) 'damaged)
  ;; Move him back to the initial spawn position.
  (setf (raylib:vector2-x (fighter-pos fighter)) +fighter-spawn-x+)
  (setf (raylib:vector2-y (fighter-pos fighter)) +fighter-spawn-y+)
  (setf (raylib:rectangle-x (fighter-bbox fighter)) +fighter-spawn-x+)
  (setf (raylib:rectangle-y (fighter-bbox fighter)) +fighter-spawn-y+)
  ;; Turn off the beam if it were firing.
  (let ((beam (fighter-beam fighter)))
    (setf (beam-shooting? beam) nil)
    (setf (raylib:vector2-x (beam-pos beam)) (+ (beam-x-offset beam) +fighter-spawn-x+))
    (setf (raylib:vector2-y (beam-pos beam)) (+ +beam-y-offset+ +fighter-spawn-y+))
    (setf (raylib:rectangle-x (beam-bbox beam)) (+ (beam-x-offset beam) +fighter-spawn-x+))
    (setf (raylib:rectangle-y (beam-bbox beam)) (+ +beam-y-offset+ +fighter-spawn-y+))))

;; --- Generics --- ;;

(defmethod tick! ((fighter fighter) fc)
  "Resetting of the fighter's flashing respawn status, etc."
  (cond ((and (eq 'hit (fighter-status fighter))
              (> (- fc (fighter-status-fc fighter)) +frame-rate+))
         (setf (fighter-status fighter) 'ok)
         (setf (fighter-status-fc fighter) fc)
         (setf (animated-active (fighter-animated fighter)) 'idle))))

(defmethod draw ((fighter fighter) fc)
  (draw-animated (fighter-animated fighter) (fighter-pos fighter) fc))

(defmethod pos ((fighter fighter))
  (fighter-pos fighter))

(defmethod bbox ((fighter fighter))
  (fighter-bbox fighter))

(defun distance-of-move! (fighter)
  "What's the distance to be moved on this frame? Mutable and frame-specific."
  (if (fighter-warp-next? fighter)
      (progn (setf (fighter-warp-next? fighter) nil)
             +warp-distance+)
      2.0))

(defmethod move! ((fighter fighter))
  "Move the fighter depending on the current button presses."
  (let* ((pos    (fighter-pos fighter))
         (bbox   (fighter-bbox fighter))
         (beam   (fighter-beam fighter))
         (b-pos  (beam-pos (fighter-beam fighter)))
         (b-bbox (beam-bbox (fighter-beam fighter))))
    (when (or (raylib:is-key-down +key-right+)
              (raylib:is-gamepad-button-down +gamepad+ +gamepad-right+))
      (let* ((dist (distance-of-move! fighter))
             (new  (min +112.0 (+ dist (raylib:vector2-x pos)))))
        (setf (raylib:vector2-x pos) new)
        (setf (raylib:rectangle-x bbox) new)
        (setf (raylib:vector2-x b-pos) (+ new (beam-x-offset beam)))
        (setf (raylib:rectangle-x b-bbox) (+ new (beam-x-offset beam)))))
    (when (or (raylib:is-key-down +key-left+)
              (raylib:is-gamepad-button-down +gamepad+ +gamepad-left+))
      (let* ((dist (distance-of-move! fighter))
             (new  (max -128.0 (- (raylib:vector2-x pos) dist))))
        (setf (raylib:vector2-x pos) new)
        (setf (raylib:rectangle-x bbox) new)
        (setf (raylib:vector2-x b-pos) (+ new (beam-x-offset beam)))
        (setf (raylib:rectangle-x b-bbox) (+ new (beam-x-offset beam)))))
    (when (or (raylib:is-key-down +key-down+)
              (raylib:is-gamepad-button-down +gamepad+ +gamepad-down+))
      (let* ((dist (distance-of-move! fighter))
             (new  (min +104.0 (+ dist (raylib:vector2-y pos)))))
        (setf (raylib:vector2-y pos) new)
        (setf (raylib:rectangle-y bbox) new)
        (setf (raylib:vector2-y b-pos) (+ new +beam-y-offset+))
        (setf (raylib:rectangle-y b-bbox) (+ new +beam-y-offset+))))
    (when (or (raylib:is-key-down +key-up+)
              (raylib:is-gamepad-button-down +gamepad+ +gamepad-up+))
      (let* ((dist (distance-of-move! fighter))
             (new  (max -120.0 (- (raylib:vector2-y pos) dist))))
        (setf (raylib:vector2-y pos) new)
        (setf (raylib:rectangle-y bbox) new)
        (setf (raylib:vector2-y b-pos) (+ new +beam-y-offset+))
        (setf (raylib:rectangle-y b-bbox) (+ new +beam-y-offset+))))))
