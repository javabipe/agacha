SHELL := /bin/bash

# Usa as ferramentas do PATH (Homebrew) ou, se ausentes, as baixadas em .tools/bin
TOOLS     := $(CURDIR)/.tools/bin
XCODEGEN  := $(shell command -v xcodegen 2>/dev/null || echo $(TOOLS)/xcodegen)
SWIFTLINT := $(shell command -v swiftlint 2>/dev/null || echo $(TOOLS)/swiftlint)

PROJECT   := Agacha.xcodeproj
SCHEME    := Agacha
PACKAGES  := AganhaCore AganhaVision AganhaAudio AganhaUI AganhaStore
# Pacotes com testes que rodam no macOS via `swift test`
TESTED    := AganhaCore AganhaVision

.PHONY: project build test lint clean

project:
	$(XCODEGEN) generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

test:
	@set -e; for p in $(TESTED); do \
		echo "== swift test: $$p"; \
		swift test --package-path Packages/$$p; \
	done

lint:
	$(SWIFTLINT) lint --quiet

clean:
	rm -rf $(PROJECT) App/Info.plist
	@for p in $(PACKAGES); do rm -rf Packages/$$p/.build; done
