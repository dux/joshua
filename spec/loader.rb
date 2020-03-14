ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'bundler'

Bundler.require :default, :test

require_relative './base'
