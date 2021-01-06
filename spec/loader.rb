ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'bundler'

Bundler.require :test

require_relative './base'
