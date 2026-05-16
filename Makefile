.PHONY: build run test clean xcode

build:
	swift build

run:
	swift run Fizzy

test:
	swift test

clean:
	swift package clean
	rm -rf .build

xcode:
	open Package.swift
