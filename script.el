(switch-to-buffer "*Messages*")
(split-window-below)
(setq inhibit-startup-screen t)

(add-to-list 'load-path "~/.emacs.d/lisp/")
(package-initialize)

(require 'project)

(defun project-find-go-module (dir)
	(when-let ((root (locate-dominating-file dir "go.mod")))
		(cons 'go-module root)))

(cl-defmethod project-root ((project (head go-module)))
	(cdr project))

(add-hook 'project-find-functions #'project-find-go-module)

(require 'company)
(global-company-mode)

(require 'yasnippet)
(yas-global-mode 1)

(defun eglot-organize-imports ()
	"Offer to execute the source.organizeImports code action."
	(interactive)
	(unless (eglot--server-capable :codeActionProvider)
		(eglot--error "Server can't execute code actions!"))
	(let* ((server (eglot--current-server-or-lose))
	       (actions (jsonrpc-request
	                 server
	                 :textDocument/codeAction
	                 (list :textDocument (eglot--TextDocumentIdentifier))))
	       (action (cl-find-if
	                (jsonrpc-lambda (&key kind &allow-other-keys)
	                  (string-equal kind "source.organizeImports" ))
	                actions)))
		(when action
			(eglot--dcase action
				(((Command) command arguments)
					(eglot-execute-command server (intern command) arguments))
				(((CodeAction) edit command)
					(when edit (eglot--apply-workspace-edit edit))
					(when command
						(eglot--dbind ((Command) command arguments) command
							(eglot-execute-command server (intern command) arguments))))))))

(require 'go-mode)
(with-eval-after-load "eglot"
	(progn
		(add-to-list 'eglot-server-programs '(go-mode . ("gopls" "-rpc.trace" "-logfile=/usr/local/google/home/bcmills/tmp/gopls.log")))
		(defun eglot-install-save-hook ()
			(add-hook 'before-save-hook #'eglot-organize-imports -20 t)
			(add-hook 'before-save-hook #'eglot-format-buffer -10 t))
		(add-hook 'go-mode-hook #'eglot-install-save-hook)
		(add-hook 'go-mode-hook #'eglot-ensure)))

(require 'eglot)

(defun edit-and-save-buffer (server)
	(switch-to-buffer "main.go")
	(insert-char ?\s)
	(save-buffer))
(add-hook 'eglot-connect-hook 'edit-and-save-buffer)

(find-file "./main.go")
