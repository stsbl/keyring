GPGHOME := $(shell mktemp -d)
KEYRING = "stsbl.gpg"
GPG = gpg --homedir $(GPGHOME)

.PHONY: $(KEYRING)

$(KEYRING):
	@# ensure that there are no duplicate keys; this should help prevent
	@# simple mistakes like accidentally exporting or copying the wrong key
	@# from a smartcard
	@if fdupes keys | grep -q .; \
	  then \
	    echo "ERROR! Duplicate keys!" >&2; \
	    fdupes keys; \
	    exit 1; \
	  fi

	@# import all keys from keys/ into a new keyring
	@$(GPG) --import keys/*.pub

	@# remove the superfluous encryption/authentication subkeys that have
	@# no relevance for APT whatsoever
	@gpg --list-keys --with-colon | \
	  awk -F: '$$1 == "pub" { print $$5 }' | while read i; \
	  do \
	    echo "removing superfluous subkeys of key $$i"; \
	    echo y | $(GPG) --batch --command-fd=0 \
	      --edit-key "$$i" "key 2" delkey save 2> /dev/null; \
	    echo y | $(GPG) --batch --command-fd=0 \
	      --edit-key "$$i" "key 1" delkey save 2> /dev/null; \
	  done

	@# export all public keys to classic GPG keyring (APT cannot unterstand
	@# new-style GPG keyboxes)
	@$(GPG) --output "$@" --export repository@stsbl.de

	@# make exported keyring visible for dh_iservinstall3 (uses git ls-files)
	@git add --intent-to-add --force "$@"; \

	@chmod -v 0644 $@
	@rm -f "$@"~

	@# remove temporary GPG home
	@rm -rfv "$(GPGHOME)";

.PHONY: clean
clean:
	@rm -vf "$(KEYRING)"
	@git add -A
