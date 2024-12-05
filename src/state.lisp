;;; The mutable state of the running game.
;;;
;;; Calling `game' initialises it, and likewise `ungame' unloads various
;;; textures that had been loaded into the GPU by Raylib.

(in-package :aero-fighter)

#+nil
(launch)

;; NOTE: When you add a texture here, make sure to unload it in `ungame' below.
(defstruct (sprites (:constructor @sprites))
  "A bank of various sprites and their loaded textures."
  (fighter   (sprite #p"assets/fighter.json"))
  (beam-2    (sprite #p"assets/beam-2.json"))
  (beam-4    (sprite #p"assets/beam-4.json"))
  (beam-6    (sprite #p"assets/beam-6.json"))
  (beam-8    (sprite #p"assets/beam-8.json"))
  (beam-10   (sprite #p"assets/beam-10.json"))
  (beam-12   (sprite #p"assets/beam-12.json"))
  (beam-14   (sprite #p"assets/beam-14.json"))
  (beam-16   (sprite #p"assets/beam-16.json"))
  (beam-18   (sprite #p"assets/beam-18.json"))
  (blob      (sprite #p"assets/blob.json"))
  (tank      (sprite #p"assets/tank.json"))
  (building  (sprite #p"assets/building.json"))
  (evil-ship (sprite #p"assets/evil-fighter.json"))
  (bomb      (sprite #p"assets/bomb.json"))
  (wide      (sprite #p"assets/wide-laser.json"))
  (explosion (sprite #p"assets/explosion.json"))
  (hud       (sprite #p"assets/hud.json"))
  (little-f  (sprite #p"assets/little-fighter.json"))
  (little-b  (sprite #p"assets/little-bomb.json"))
  (little-p  (sprite #p"assets/little-beam.json"))
  (numbers   (sprite #p"assets/numbers.json"))
  (level     (sprite #p"assets/level-x.json"))
  (missile   (sprite #p"assets/missile.json"))
  (shield    (sprite #p"assets/shield.json"))
  (shield-aura (sprite #p"assets/shield-aura.json"))
  (cannon-bulb (sprite #p"assets/cannon-bulb.json"))
  (cannon-beam (sprite #p"assets/cannon-beam.json"))
  (ground    (raylib:load-texture "assets/lighter-ground.png"))
  (road      (raylib:load-texture "assets/road.png"))
  (shadow    (raylib:load-texture "assets/shadow.png"))
  (blob-shadow (raylib:load-texture "assets/blob-shadow.png")))

;; FIXME: 2024-11-07 Can the hash tables for the blobs and tanks be merged?
;;
;; 2024-11-21 Probably yes, because it can still be useful to handle them
;; separately, for instance for calling `tick!' on the tanks but not the blobs.
;; Blobs don't have any internal time-based state.
(defstruct game
  "The state of the running game."
  (camera  (camera) :type raylib:camera-2d)
  (sprites nil :type sprites)
  (fighter nil :type fighter)
  (warp-ghost nil :type ghost)
  ;; The point after which the next beam/shield powerup should spawn.
  (powerup-threshold +powerup-spawn-interval+ :type fixnum)
  ;; The key is the frame number upon which the blob was spawned.
  (blobs      (make-hash-table :size 16) :type hash-table)
  (tanks      (make-hash-table :size 16) :type hash-table)
  (evil-ships (make-hash-table :size 16) :type hash-table)
  (buildings  (make-hash-table :size 16) :type hash-table)
  (cannons    (make-hash-table :size 16) :type hash-table)
  (missiles   (make-hash-table :size 16) :type hash-table)
  (powerups   (make-hash-table :size 16) :type hash-table)
  (ground     nil :type hash-table)
  (road       nil :type hash-table)
  ;; TODO: 2024-11-14 Consider generalising this to any other on-screen
  ;; animations.
  (explosions (make-hash-table :size 16) :type hash-table)
  (frame 0 :type fixnum)
  (lives 3 :type fixnum)
  (score 0 :type fixnum)
  ;; Waiting / Playing / Dead
  (mode  'playing :type symbol)
  (level 1 :type fixnum)
  ;; The point after which the level should increase.
  (level-thresh +level-progression-interval+ :type fixnum))

(defun @game ()
  "Initialise the various game resources."
  (let ((sprites (@sprites)))
    (make-game :sprites sprites
               :warp-ghost (@ghost (sprites-fighter sprites))
               :fighter (@fighter (sprites-fighter sprites)
                                  (sprites-beam-2 sprites)
                                  (sprites-shield-aura sprites)
                                  (sprites-shadow sprites))
               :ground (entire-ground (sprites-ground sprites))
               :road (entire-road (sprites-road sprites)))))

;; TODO: 2024-11-12 Should I just reconstruct the `game' entirely instead of
;; doing all this manual resetting?
;;
;; Disdvantage: it would reread all the sprite data, reset the camera, and reset
;; the current frame number.
;;
;; 2024-11-23 Yup I'm leaning towards a No.
(defun reset-game! (game)
  "Reset the `game' to an initial, reusable state."
  (setf (game-lives game) 3)
  (clear-all-enemies! game)
  (setf (game-buildings game) (make-hash-table :size 16))
  (setf (game-cannons game) (make-hash-table :size 16))
  (setf (game-powerups game) (make-hash-table :size 16))
  (setf (game-explosions game) (make-hash-table :size 16))
  (setf (game-score game) 0)
  (setf (game-level game) 1)
  (setf (game-mode game) 'playing)
  (setf (game-powerup-threshold game) +powerup-spawn-interval+)
  (setf (game-level-thresh game) +level-progression-interval+)
  (let ((fighter (game-fighter game)))
    (setf (fighter-bombs fighter) 3)
    (setf (fighter-shielded? fighter) nil)
    (setf (fighter-beam fighter)
          (@beam (->> game game-sprites sprites-beam-2)
                 (fighter-pos fighter)
                 (raylib:rectangle-width (fighter-bbox fighter))
                 +beam-y-offset+))))

(defun clear-all-enemies! (game)
  "From a bomb or otherwise, clear all the damageable enemies."
  (setf (game-blobs game)      (make-hash-table :size 16))
  (setf (game-tanks game)      (make-hash-table :size 16))
  (setf (game-evil-ships game) (make-hash-table :size 16))
  (setf (game-missiles game)   (make-hash-table :size 16)))

(defun beam-by-level (game)
  "Yield a beam sprite for enemies according to the current level."
  (let ((sprites (game-sprites game)))
    (case (game-level game)
      (1 (sprites-beam-2 sprites))
      (2 (sprites-beam-2 sprites))
      (3 (sprites-beam-4 sprites))
      (4 (sprites-beam-4 sprites))
      (5 (sprites-beam-6 sprites))
      (6 (sprites-beam-6 sprites))
      (t (sprites-beam-8 sprites)))))

(defun beam-upgrade-count (sprites beam)
  "The rank, so to speak, of the current beam."
  (cond ((eq beam (sprites-beam-2 sprites))  0)
        ((eq beam (sprites-beam-4 sprites))  1)
        ((eq beam (sprites-beam-6 sprites))  2)
        ((eq beam (sprites-beam-8 sprites))  3)
        ((eq beam (sprites-beam-10 sprites)) 4)
        ((eq beam (sprites-beam-12 sprites)) 5)
        ((eq beam (sprites-beam-14 sprites)) 6)
        ((eq beam (sprites-beam-16 sprites)) 7)
        ((eq beam (sprites-beam-18 sprites)) 8)
        (t (error "Unknown sprite! Is it really a beam?"))))

(defun max-beam? (sprites beam)
  "Is this beam already the biggest one?"
  (eq beam (sprites-beam-18 sprites)))

(defun upgrade-beam (sprites beam)
  "Yield the sprite of the beam one level higher than the current one."
  (cond ((eq beam (sprites-beam-2 sprites))  (sprites-beam-4 sprites))
        ((eq beam (sprites-beam-4 sprites))  (sprites-beam-6 sprites))
        ((eq beam (sprites-beam-6 sprites))  (sprites-beam-8 sprites))
        ((eq beam (sprites-beam-8 sprites))  (sprites-beam-10 sprites))
        ((eq beam (sprites-beam-10 sprites)) (sprites-beam-12 sprites))
        ((eq beam (sprites-beam-12 sprites)) (sprites-beam-14 sprites))
        ((eq beam (sprites-beam-14 sprites)) (sprites-beam-16 sprites))
        ((eq beam (sprites-beam-16 sprites)) (sprites-beam-18 sprites))
        ((max-beam? sprites beam)            (sprites-beam-18 sprites))
        (t (error "Unknown sprite! Is it really a beam?"))))

(defun downgrade-beam (sprites beam)
  "Yield the sprite of the beam one level lower than the current one."
  (cond ((eq beam (sprites-beam-2 sprites))  (sprites-beam-2 sprites))
        ((eq beam (sprites-beam-4 sprites))  (sprites-beam-2 sprites))
        ((eq beam (sprites-beam-6 sprites))  (sprites-beam-4 sprites))
        ((eq beam (sprites-beam-8 sprites))  (sprites-beam-6 sprites))
        ((eq beam (sprites-beam-10 sprites)) (sprites-beam-8 sprites))
        ((eq beam (sprites-beam-12 sprites)) (sprites-beam-10 sprites))
        ((eq beam (sprites-beam-14 sprites)) (sprites-beam-12 sprites))
        ((eq beam (sprites-beam-16 sprites)) (sprites-beam-14 sprites))
        ((eq beam (sprites-beam-18 sprites)) (sprites-beam-16 sprites))
        (t (error "Unknown sprite! Is it really a beam?"))))

(defun camera ()
  "Initialise a 2D Camera."
  (let* ((center-x (/ +screen-width+ 2.0))
         (center-y (/ +screen-height+ 2.0))
         (offset   (raylib:make-vector2 :x center-x :y center-y))
         (target   (raylib:make-vector2 :x 0.0 :y 0.0)))
    (raylib:make-camera-2d :offset offset :target target :rotation 0.0 :zoom 3.0)))

(defun ungame (game)
  "Release various resources."
  (let ((sprites (game-sprites game)))
    (raylib:unload-texture (sprite-texture (sprites-fighter sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-2 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-4 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-6 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-8 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-10 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-12 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-14 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-16 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-beam-18 sprites)))
    (raylib:unload-texture (sprite-texture (sprites-blob sprites)))
    (raylib:unload-texture (sprite-texture (sprites-tank sprites)))
    (raylib:unload-texture (sprite-texture (sprites-building sprites)))
    (raylib:unload-texture (sprite-texture (sprites-evil-ship sprites)))
    (raylib:unload-texture (sprite-texture (sprites-bomb sprites)))
    (raylib:unload-texture (sprite-texture (sprites-wide sprites)))
    (raylib:unload-texture (sprite-texture (sprites-explosion sprites)))
    (raylib:unload-texture (sprite-texture (sprites-hud sprites)))
    (raylib:unload-texture (sprite-texture (sprites-little-f sprites)))
    (raylib:unload-texture (sprite-texture (sprites-little-b sprites)))
    (raylib:unload-texture (sprite-texture (sprites-little-p sprites)))
    (raylib:unload-texture (sprite-texture (sprites-numbers sprites)))
    (raylib:unload-texture (sprite-texture (sprites-level sprites)))
    (raylib:unload-texture (sprite-texture (sprites-missile sprites)))
    (raylib:unload-texture (sprite-texture (sprites-cannon-bulb sprites)))
    (raylib:unload-texture (sprite-texture (sprites-cannon-beam sprites)))
    (raylib:unload-texture (sprite-texture (sprites-shield sprites)))
    (raylib:unload-texture (sprite-texture (sprites-shield-aura sprites)))
    (raylib:unload-texture (sprites-ground sprites))
    (raylib:unload-texture (sprites-road sprites))
    (raylib:unload-texture (sprites-shadow sprites))
    (raylib:unload-texture (sprites-blob-shadow sprites))))
