(set-env! :dependencies '[[org.clojure/clojure "1.8.0"]]
          :source-paths #{"src/"})

(task-options!
 jar {:main 'playclj.core}
 aot {:all true})

(deftask build
  "Create a standalone jar file."
  []
  (comp (aot) (uber) (jar) (target)))
