# frozen_string_literal: true
require 'sinatra/jsonapi'
require 'sinja/sequel'

module Sinatra
  register JSONAPI::Sequel
end
