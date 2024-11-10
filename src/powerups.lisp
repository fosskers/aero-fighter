;;; The mechanics of various fighter powerups.

(in-package :aero-fighter)

#+nil
(launch)

;; --- General --- ;;

(defun despawn-powerups! (powerups fc)
  "Despawn old powerups if enough time has passed."
  (t:transduce (t:comp (t:filter (lambda (pu) (expired? (cdr pu) fc)))
                       (t:map (lambda (pu) (remhash (car pu) powerups))))
               #'t:for-each powerups))

;; --- Wide Laser --- ;;

(defstruct wide
  "A wide laser powerup."
  (animated nil :type animated)
  (pos      nil :type raylib:vector2)
  (bbox     nil :type raylib:rectangle)
  (spawn-fc 0   :type fixnum))

(defun wide (sprite fc)
  "A smart-consturctor for `wide'."
  (let* ((pos      (random-position))
         (animated (make-animated :sprite sprite))
         (rect     (bounding-box animated)))
    (make-wide :animated animated
               :pos pos
               :spawn-fc fc
               :bbox (raylib:make-rectangle :x (raylib:vector2-x pos)
                                            :y (raylib:vector2-y pos)
                                            :width (raylib:rectangle-width rect)
                                            :height (raylib:rectangle-height rect)))))

(defun maybe-spawn-wide! (game)
  "Spawn a `wide' laser powerup depending on the current frame."
  (let ((fc (game-frame game)))
    ;; BUG: 2024-11-08 Make more robust. Use randomness, etc. Currently there's
    ;; a bug here if a bomb and wide laser would spawn on the same framee.
    ;;
    ;; 2024-11-10 Actually JP says this is supposed to be based on points, but I
    ;; need more clarification.
    (when (and (zerop (mod fc (* 30 +frame-rate+))))
      (let ((wide (wide (sprites-wide (game-sprites game)) fc)))
        (setf (gethash fc (game-powerups game)) wide)))))

(defmethod pos ((wide wide))
  (wide-pos wide))

(defmethod bbox ((wide wide))
  (wide-bbox wide))

(defmethod draw ((wide wide) fc)
  (draw-animated (wide-animated wide)
                 (wide-pos wide)
                 fc))

(defmethod tick! ((wide wide) fc)
  "Start to despawn the `wide' if too much time has passed."
  (when (> (- fc (wide-spawn-fc wide))
           +powerup-newness-timeout+)
    (setf (animated-active (wide-animated wide)) 'flashing)))

(defmethod expired? ((wide wide) fc)
  (> (- fc (wide-spawn-fc wide))
     +powerup-spawn-timeout+))

;; --- Bombs --- ;;

(defstruct ammo
  "Extra bomb ammunition."
  (animated nil :type animated)
  (pos      nil :type raylib:vector2)
  (bbox     nil :type raylib:rectangle)
  (spawn-fc 0   :type fixnum))

(defun ammo (sprite fc)
  "A smart-consturctor for `ammo'."
  (let* ((pos      (random-position))
         (animated (make-animated :sprite sprite))
         (rect     (bounding-box animated)))
    (make-ammo :animated animated
               :pos pos
               :spawn-fc fc
               :bbox (raylib:make-rectangle :x (raylib:vector2-x pos)
                                            :y (raylib:vector2-y pos)
                                            :width (raylib:rectangle-width rect)
                                            :height (raylib:rectangle-height rect)))))

(defun maybe-spawn-ammo! (game)
  "Spawn some bomb ammo depending on the current frame."
  (let ((fighter (game-fighter game))
        (fc (game-frame game)))
    ;; TODO: 2024-11-08 Make more robust. Use randomness, etc.
    (when (and (< (fighter-bombs fighter) +bomb-max-capacity+)
               (zerop (mod fc (* 20 +frame-rate+))))
      (let ((ammo (ammo (sprites-bomb (game-sprites game)) fc)))
        (setf (gethash fc (game-powerups game)) ammo)))))

(defmethod pos ((ammo ammo))
  (ammo-pos ammo))

(defmethod bbox ((ammo ammo))
  (ammo-bbox ammo))

(defmethod draw ((ammo ammo) fc)
  (draw-animated (ammo-animated ammo)
                 (ammo-pos ammo)
                 fc))

(defmethod tick! ((ammo ammo) fc)
  "Start to despawn the `ammo' if too much time has passed."
  (when (> (- fc (ammo-spawn-fc ammo))
           +powerup-newness-timeout+)
    (setf (animated-active (ammo-animated ammo)) 'flashing)))

(defmethod expired? ((ammo ammo) fc)
  (> (- fc (ammo-spawn-fc ammo))
     +powerup-spawn-timeout+))