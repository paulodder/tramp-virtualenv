(require 'tramp)

(if (boundp 'enable-remote-dir-locals)
    (setq enable-remote-dir-locals t))

(defcustom tramp-virtualenv-venvs-dir "~/.virtualenvs"
  "Directory in which virtualenvs are stored")

(defalias 'venv-workon-tramp 'tramp-virtualenv-workon)

(defun tramp-virtualenv--bin-dir ()
  (concat tramp-virtualenv-dir "/bin"))

(defun tramp-virtualenv (&optional dir)
  (progn
    ;;(message "entering tramp-virtualenv")
    (if (and (boundp 'dir)
             dir)
        (progn
          ;;(message "dir")
          (set (make-local-variable 'tramp-virtualenv-dir)
               dir)))
    (if (and (boundp 'tramp-virtualenv-dir)
             tramp-virtualenv-dir)
        (progn
          (set (make-local-variable 'tramp-virtualenv-mode-line-string)
               (tramp--virtualenv-format-mode-line-string))
          (tramp-virtualenv-minor-mode t)
          (let ((vec (if (tramp-tramp-file-p (buffer-file-name))
                         (tramp-dissect-file-name (buffer-file-name))
                       nil)))
            (if (or (not (boundp 'tramp-virtualenv-last-dir))
                    (not (equal tramp-virtualenv-dir tramp-virtualenv-last-dir))
                    (not (boundp 'tramp-virtualenv-last-vec))
                    (not (equal vec tramp-virtualenv-last-vec)))
                (progn
                  ;;(message "new tramp-virtualenv-dir")
                  (if vec
                      (let* ((proc (tramp-get-connection-process vec))
                             (new-remote-path (let ((path (tramp-get-remote-path vec)))
                                                (setq path (delete (tramp-virtualenv--bin-dir)
                                                                   path))
                                                (add-to-list 'path
                                                             (tramp-virtualenv--bin-dir))
                                                path)))
                        ;;(message "tramp-virtualenv remote")
                        (tramp-send-command vec
                                            (format "VIRTUAL_ENV=%s; export VIRTUAL_ENV"
                                                    tramp-virtualenv-dir))
                        (setq tramp-remote-path (delete (tramp-virtualenv--bin-dir)
                                                        tramp-remote-path))
                        (add-to-list 'tramp-remote-path
                                     (tramp-virtualenv--bin-dir))
                        (tramp-set-connection-property vec "remote-path"
                                                       new-remote-path)
                        (tramp-set-connection-property proc "remote-path"
                                                       new-remote-path)
                        (tramp-set-remote-path vec))
                    (progn
                      ;;(message "tramp-virtualenv local")
                      (setenv "VIRTUAL_ENV" tramp-virtualenv-dir)
                      (setq exec-path (delete (tramp-virtualenv--bin-dir)
                                              exec-path))
                      (add-to-list 'exec-path
                                   (tramp-virtualenv--bin-dir))
                      (setenv "PATH"
                              (mapconcat 'identity exec-path ":"))))
                  (setq tramp-virtualenv-last-dir tramp-virtualenv-dir)
                  (setq tramp-virtualenv-last-vec vec)))))
      (tramp-virtualenv-minor-mode -1))))

(add-hook 'post-command-hook 'tramp-virtualenv)

(defun tramp-virtualenv--get-venv-dir ()
  "return remote venv dir based on default-directory variable"
  (let ((remote-vec (tramp-dissect-file-name default-directory)))
    (concat "/"
            (tramp-file-name-method remote-vec)
            ":"
            (tramp-file-name-user remote-vec)
            "@"
            (tramp-file-name-host-port remote-vec)
            ":"
            tramp-virtualenv-venvs-dir)))

(defun tramp-virtualenv--get-remote-venv-names ()
  "return sequence of remote virtualenv names"
  (seq-filter (lambda (f)
                (not (string-prefix-p "." f)))
              (directory-files (tramp-virtualenv--get-venv-dir))))

(defun tramp-virtualenv--choose-venv ()
  (completing-read "Choose a virtualenv:"
                   (tramp-virtualenv--get-remote-venv-names)))

(defun tramp-virtualenv-workon ()
  (interactive)
  (tramp-virtualenv (concat tramp-virtualenv-venvs-dir
                            "/"
                            (tramp-virtualenv--choose-venv))))



(defun tramp--virtualenv-format-mode-line-string ()
  (concat " "
          (nth 0
               (reverse (split-string tramp-virtualenv-dir "/")))))

(define-minor-mode tramp-virtualenv-minor-mode
  nil nil tramp-virtualenv-mode-line-string
  nil :group 'tramp-virtualenv)

(provide 'tramp-virtualenv)
