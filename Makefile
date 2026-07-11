.PHONY: app run stop dmg pkg quick-actions uninstall-quick-actions clean

app:
	bash scripts/build-app.sh

run: app
	@pkill -x ScreenRec 2>/dev/null || true
	open build/ScreenRec.app

stop:
	@pkill -x ScreenRec 2>/dev/null || true

dmg:
	bash scripts/make-dmg.sh

pkg:
	bash scripts/make-pkg.sh

quick-actions:
	bash scripts/install-quick-actions.sh

uninstall-quick-actions:
	bash scripts/uninstall-quick-actions.sh

clean:
	rm -rf .build build
