(ns playclj.core
  (:require [clojure.java.io :as io]
            [clojure.core.reducers :as r])
  (:import [java.awt Canvas Graphics2D]
           [java.awt.image BufferedImage MemoryImageSource])
  (:gen-class))

(def ^:const N 1000)
(def ^:const depth 200)
(def ^:const escape2 400.0)
(def ^:const l2 (Math/log 2))
(def ^:const color-map
  [[ 0.0 0.0 0.5 ] 
   [ 0.0 0.0 1.0 ] 
   [ 0.0 0.5 1.0 ] 
   [ 0.0 1.0 1.0 ] 
   [ 0.5 1.0 0.5 ] 
   [ 1.0 1.0 0.0 ] 
   [ 1.0 0.5 0.0 ] 
   [ 1.0 0.0 0.0 ] 
   [ 0.5 0.0 0.0 ] 
   [ 0.5 0.0 0.0 ] 
   [ 1.0 0.0 0.0 ] 
   [ 1.0 0.5 0.0 ] 
   [ 1.0 1.0 0.0 ] 
   [ 0.5 1.0 0.5 ] 
   [ 0.0 1.0 1.0 ] 
   [ 0.0 0.5 1.0 ] 
   [ 0.0 0.0 1.0 ] 
   [ 0.0 0.0 0.5 ] 
   [ 0.0 0.0 0.0 ]])
(def ^:const stops (- (count color-map) 1))

(deftype Complex [^double real ^double imag])
(def ^:const czero (Complex. 0.0 0.0))

(defn csqr [^Complex a]
  (let [ra (.real a) ia (.imag a)]
    (Complex. (- (* ra ra) (* ia ia))
              (* ra ia 2.0))))

(defn cadd [^Complex a ^Complex b]
  (Complex. (+ (.real a) (.real b))
            (+ (.imag a) (.imag b))))

(defn cmag2 [^Complex a]
  (let [ra (.real a) ia (.imag a)]
    (+ (* ra ra) (* ia ia))))

(defn log2 [^double n]
  (/ (Math/log n) l2))

(defn level [^long k ^double m]
  (Math/log (- (+ k 1) (log2 (/ (Math/log (max m escape2)) 2.0)))))

(defn mandel [^double x ^double y]
  (let [z0 (Complex.  (- (* 3.0 (/ x N)) 2.0)
                      (- (* 3.0 (/ y N)) 1.5))]
    (loop [z czero k 0]
      (let [m (cmag2 z)]
        (if (and (< k depth) (< m escape2))
          (recur (cadd (csqr z) z0)
                 (inc k))
          (level k m))))))

(defn interpolate [^double d ^double v0 ^double v1]
  (int (* (+ (* d (- v1 v0)) v0) 255.0)))

(defn map-color [^double l]
  (let [x (* l stops)
        bin (int x)]
    (if (< bin stops)
      (let [d (- x bin)
            [r0 g0 b0] (color-map bin)
            [r1 g1 b1] (color-map (inc bin))
            r (interpolate d r0 r1)
            g (interpolate d g0 g1)
            b (interpolate d b0 b1)]
        (bit-or 0xff000000
                (bit-shift-left r 16)
                (bit-shift-left g 8)
                b))
      0xff000000)))

(defn scaler [^double min-val ^double max-val]
  (let [r (- max-val min-val)]
    (fn [^double x]
      (let [l (/ (- x min-val) r)]
        (map-color l)))))

(defn render-image [bytes]
  (let [imgsrc (MemoryImageSource. N N bytes 0 N)
        img (BufferedImage. N N BufferedImage/TYPE_INT_ARGB)
        ^Graphics2D g (.getGraphics img)]
    (.drawImage g (.createImage (Canvas.) imgsrc)
                nil nil)
    img))

(defn write-image [img]
  (javax.imageio.ImageIO/write
   img "png" (java.io.File. "mandel.png")))

(defn -main [& args]
  (let [arr (time (for [y (range N) x (range N)] (mandel x y)))
        max-val (time (apply max arr))
        min-val (time (apply min arr))
        result (time (int-array (map (scaler min-val max-val) arr)))
        ]
    (time (write-image (render-image result)))))
