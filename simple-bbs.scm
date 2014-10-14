#!/usr/bin/env gosh

;;;
;;; simple bbs on heroku
;;;

(use dbi)
(use dbd.pg)
(use gauche.collection)
(use gauche.parameter)
(use gauche.parseopt)
(use makiki)
(use text.html-lite)
(use rfc.uri)
(use www.cgi)

(use srfi-13)
(use srfi-98)

(define *db-name* #f)
(define db (make-parameter #f))
(define-syntax with-db
  (syntax-rules ()
	((with-db (db dsn) . body)
	 (parameterize ((db (dbi-connect dsn)))
	  (guard
		  (e (else (dbi-close (db)) (raise e)))
		(begin0
		  (begin . body)
		  (dbi-close (db))))))))

(define (userinfo-to-keyvalue userinfo)
  (if (string-scan userinfo ":")
	  (format "user=~a;password=~a"
			  (string-scan userinfo ":" 'before)
			  (string-scan userinfo ":" 'after))
	  #`"user=,userinfo"))

(define (uri-to-keyvalue uri)
  (receive (scheme userinfo host port path query fragment)
	  (uri-parse uri)
	(string-join
	 (cond-list
	  (userinfo => (cut userinfo-to-keyvalue <>))
	  (host #`"host=,host")
	  (port #`"port=,port")
	  (path #`"dbname=,(substring/shared path 1)")
	  (query => (cut regexp-replace-all #/&/ <> ";"))
	  ) ";")))

(define (add-message name message)
  (clean-message)
  (with-db (db *db-name*)
    (let ((query (dbi-prepare (db)
	  "insert into bbs(name, message) values(?, ?)")))
		(dbi-execute query name message))))

(define (clean-message)
  (with-db (db *db-name*)
    (let* ((query (dbi-prepare (db)
			"select min(added) from (select added from bbs order by added desc limit 100) b"))
		   (result (dbi-execute query))
		   (min-added (car
			 (map (lambda (row)
					(dbi-get-value row 0))
				  result)))
		   (delete (dbi-prepare (db)
			"delete from bbs where added < ?")))
	  (unless (string-null? min-added)
		(dbi-execute delete min-added)))))

(define (get-message)
  (with-db (db *db-name*)
    (let* ((query (dbi-prepare (db)
			"select * from bbs order by added desc"))
		   (result (dbi-execute query))
		   (getter (relation-accessor result))
		   (message-list
			(map (lambda (row)
				   (list
					(cons 'name (getter row "name"))
					(cons 'message (getter row "message"))
					(cons 'added (getter row "added"))))
				 result)))
		message-list)))

(define (render-message)
  (define (render-entry entry)
    `((dt (b ,(assoc-ref entry 'name)) " "
          "(",(assoc-ref entry 'added)")")
      (dd ,(assoc-ref entry 'message))))
  `(sxml
		(html
		 (head (title "simple BBS"))
		 (body
		  (h3 "simple BBS")
		  (form (@ (method "GET") (action "/"))
				(table (tr (th "Name:")
						   (td (input (@ (type "text") (name "name")))))
					   (tr (th "Message:")
						   (td (textarea (@ (name "message") (cols 60)) "")))
					   (tr (td)
						   (td (input (@ (type "submit") (name "s") (value "Write")))))))
		  (dl ,@(append-map render-entry (get-message)))))))

(define-http-handler "/"
  (^[req app]
    (let ([name (cgi-get-parameter "name" (request-params req))]
          [message (cgi-get-parameter "message" (request-params req))])
	  (when (and name (not (string-null? name)) message (not (string-null? message)))
		(add-message name message))
      (respond/ok req (render-message)))))

(define (main args)
  (set! *db-name*
		(or (and-let* ((db-url (get-environment-variable "DATABASE_URL")))
			  #`"dbi:pg:,(uri-to-keyvalue db-url)")
			(and-let* ((db-str (get-environment-variable "DATABASE_STR")))
			  #`"dbi:pg:,db-str")))
  (let-args (cdr args)
	  ((port "p|port=s"))
	(when (and port *db-name*)
	  (start-http-server :port port
						 :access-log #t :error-log #t))
	0))

;; Local variables:
;; mode: scheme
;; end:
