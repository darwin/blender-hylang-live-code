(import
  sys
  threading
  time
  hylc.jobs
  [socketserver [ThreadingMixIn TCPServer BaseRequestHandler]])

(import [HyREPL [bencode session]])
(import [HyREPL.middleware [base eval]])

(require [hy.contrib.walk [let]])

(defclass ReplServer [ThreadingMixIn TCPServer]
  (setv allow-reuse-address True))

(defclass ReplRequestHandler [BaseRequestHandler]
  (setv session None)
  (defn handle [self]
    (print "New client" :file sys.stderr)
    (let [buf (bytearray)
          tmp None
          msg None]
      (while True
        ; receive data
        (try
          (setv tmp (.recv self.request 1024))
          (except [e OSError]
            (break)))
        (if (= (len tmp) 0)
          (break))
        (.extend buf tmp)
        ; decode buffer
        (try
          (let [decoded (bencode.decode buf)
                _ (setv msg (get decoded 0))
                rest (get decoded 1)]
            (.clear buf)
            (.extend buf rest))
          (except [e Exception]
            (print e :file sys.stderr)
            (continue)))
        ; setup session
        (if-not self.session
          (setv self.session (or (.get session.sessions (.get msg "session"))
                                 (session.Session))))
        ; request session job
        (hylc.jobs.handle_session_message self.session msg self.request)))
    (print "Client gone" :file sys.stderr)))


(defn start-server [&optional [host "127.0.0.1"] [port 1337]]
  (let [s (ReplServer (, host port) ReplRequestHandler)
        t (threading.Thread :target s.serve-forever)]
    (setv t.daemon True)
    (.start t)
    (, t s)))

(defn read-port-from-args [args]
  (if (> (len args) 0)
    (try
      (int (last args))
      (except [_ ValueError]))))

(defmain [&rest args]
  (setv port (or (read-port-from-args args) 1337))
  (while True
    (try
      (start-server "127.0.0.1" port)
      (except [e OSError]
        (setv port (inc port)))
      (else
        (print (.format "Listening on {}" port) :file sys.stderr)
        (while True
          (time.sleep 1))))))
