;;;; RFC2047 encoding.

(in-package :cl-rfc2047)

(defun encoded-word (encoding charset string)
  "Return encoded word for ENCODING, CHARSET and STRING."
  (format nil "=?~a?~a?~a?="
	  (symbol-name charset)
	  (symbol-name encoding)
	  string))

(defun encoded-words (encoding charset strings)
  "Return encoded words for ENCODING, CHARSET and STRINGS."
  (format nil (format nil "~~{~~a~~^~a~~}" *crlfsp*)
	  (loop for string in strings
	     collect (encoded-word encoding charset string))))

(defun encoded-word-content-length (charset)
  "Return maximum length of encoded word contents for CHARSET."
  (- *encoded-word-length* (+ *encoded-word-length-overhead*
			      (length (symbol-name charset)))))

(defun limited-words (pieces length word-type)
  "Return list of words no longer than LENGTH concatenated from PIECES
destructively."
  (flet ((next-word ()
	   (loop for count = 0 then (+ count (length piece))
	      for piece = (car pieces)
	      while (and piece
			 (<= (+ count (length piece))
			     length))
	      collect (pop pieces))))
    (loop for word = (next-word)
       while word collect (apply #'concatenate word-type word))))

(defun string-to-grouped-bytes (string charset)
  "Return list of byte vectors for STRING using CHARSET."
  (loop for i from 0 to (1- (length string))
     collect (string-to-octets (subseq string i (1+ i))
			       :encoding charset)))

(defun encoded-word-content-bytes (charset)
  "Return number of maximum bytes per b-encoded word using CHARSET."
  (floor (* (encoded-word-content-length charset) 0.7))) ; magic number

(defun b-split (string charset)
  "Return STRING split up in parts for b-encoding according to CHARSET."
  (limited-words (string-to-grouped-bytes string charset)
		 (encoded-word-content-bytes charset)
		 '(vector (unsigned-byte 8))))

(defun b-encode (string charset)
  "Return list of base64 encoded words for STRING using CHARSET."
  (loop for buffer in (b-split string charset)
       collect (usb8-array-to-base64-string buffer)))

(defun character-ascii (character)
  "Return ASCII code for CHARACTER or NIL."
  (let ((buffer (string-to-octets
		 (make-string 1 :initial-element character)
		 :encoding :utf-8)))
    (when (= 1 (length buffer))
      (unless (> #1=(aref buffer 0) *ascii-boundary*)
	#1#))))

(defun q-encode-p (character)
  "Predicate to test if CHARACTER needs to be q-encoded."
  (let ((code (character-ascii character)))
    (or (not code)
	(= code *ascii-newline*)
	(= code *ascii-return*)
	(= code *ascii-space*)
	(= code *ascii-equals*)
	(= code *ascii-question-mark*)
	(= code *ascii-underscore*))))

(defun should-encode-p (string)
  "*Arguments and Values:*

   _string_—a _string_.

   *Description*:

   {should-encode-p} returns _true_ if _string_ contains characters that
   need to be encoded, otherwise, returns _false_."
  (when (find-if (lambda (char)
		   (let ((code (character-ascii char)))
		     (or (not code)
			 (= code *ascii-newline*)
			 (= code *ascii-return*))))
		 string)
    t))

(defun q-encode-string (string charset)
  "Return q encoded STRING using CHARSET."
  (with-output-to-string (out)
    (loop for character across string
       do (if (q-encode-p character)
	      (loop for byte across (string-to-octets
				     string :encoding charset)
		 do (format out "=~2,'0,X" byte))
	      (write-char character out)))))

(defun q-encode-characters (string charset)
  "Return list of q encoded characters for STRING using CHARSET."
  (loop for i from 0 to (1- (length string))
     collect (q-encode-string (subseq string i (1+ i)) charset)))

(defun q-encode (string charset)
  "Return list of q encoded words for STRING using CHARSET."
  (limited-words (q-encode-characters string charset)
		 (encoded-word-content-length charset)
		 'string))

(defun encode (string &key (encoding :b) (charset :utf-8))
  "*Arguments and Values:*

   _string_—a _string_.

   _encoding_—a _keyword_.  Can either be {:b} or {:q}. The default is
   {:b}.

   _charset_—a _keyword_ denoting the character encoding used. The
   default is {:utf-8}.

   *Description*:

   {encode} returns an encoded copy of _string_. Words will be encoded
   using _encoding_ and _charset_. If _encoding_ is {:b} then the \"B\"
   encoding is used. If _encoding_ is {:q} then the \"Q\" encoding is
   used."
  (encoded-words encoding charset (ecase encoding
				    (:b (b-encode string charset))
				    (:q (q-encode string charset)))))
