ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'bundler'

Bundler.require :test

require_relative './lib/blank'
require_relative './base'
