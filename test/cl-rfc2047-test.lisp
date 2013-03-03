(in-package :cl-rfc2047-test)

(defparameter *ascii-phrases*
  '("one"
    "two three"
    "some what longer text that sould get broken up into multiple lines 123"))

(deftestsuite encode-tests () ())

(defun ensure-encoding (original encoded)
  (loop for word in (cl-ppcre:split cl-rfc2047::*crlfsp* encoded) do
       (ensure (<= (length word) 75)
	       :report "length (~A) must not be larger than 75"
	       :arguments ((length word)))
       (ensure (string= original (decode* encoded))
	       :report "~A must be equal to ~A"
	       :arguments (original (decode* encoded)))))

(defun ensure-encodings (string)
  (ensure-encoding string (encode string :encoding :b))
  (ensure-encoding string (encode string :encoding :q)))

(addtest encode-test
  (loop for word in *ascii-phrases*
     do (ensure-encodings word)))

(defun random-string (length)
  (let ((string (make-string length)))
    (loop for i from 0 to (1- length)
       do (setf (aref string i) (code-char (random 1000))))
    string))

(addtest encode-random-test
  (loop for i from 0 to 300
     do (ensure-encodings (random-string i))))

(addtest decode-known-encodings-test
  (loop for (encoded decoded)
        in '(("=?US-ASCII?Q?foo_bar=20baz?=" "foo bar baz")
	     ("=?ISO-8859-1?Q?n=e4n=F6n=fC?=" "nänönü")
	     ("=?uTf-8?b?Zm9vIGJhciBiYXo=?=" "foo bar baz"))
     do (ensure (string= decoded (decode encoded)))))

(addtest decode*-test
  (loop for (encoded decoded)
     in `(("=?US-ASCII?Q?foo_bar=20baz?="
	   "foo bar baz")
	  ("some =?US-ASCII?Q?foo_bar=20baz?=bla" 
	   "some foo bar bazbla")
	  (,(concatenate 'string "some=?uTf-8?b?Zm9v?="
			 cl-rfc2047::*crlfsp*
			 "=?uTf-8?b?YmF6?=bar")
	    "somefoobazbar")
	  ("foo" "foo"))
     for result = (decode* encoded)
     do (ensure (string= decoded result)
		:report "expected ~A, got ~A"
		:arguments (decoded result))))
