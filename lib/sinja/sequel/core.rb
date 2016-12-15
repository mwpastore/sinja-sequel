# frozen_string_literal: true
require 'forwardable'
require 'sequel'

require_relative 'pagination'

module Sinja
  module Sequel
    module Core
      extend Forwardable

      def self.prepended(base)
        base.sinja do |c|
          c.conflict_exceptions << ::Sequel::ConstraintViolation
          c.not_found_exceptions << ::Sequel::NoMatchingRow
          c.validation_exceptions << ::Sequel::ValidationFailed
          c.validation_formatter = ->(e) { e.errors.keys.zip(e.errors.full_messages) }
        end

        base.prepend Pagination if ::Sequel::Model.db.dataset.respond_to?(:paginate)
      end

      def self.included(_)
        abort "You must `prepend' Sinja::Sequel::Core, not `include' it!"
      end

      def_delegator ::Sequel::Model, :db, :database

      def_delegator :database, :transaction

      define_method :filter, proc(&:where)

      def sort(collection, fields)
        collection.order(*fields.map { |k, v| ::Sequel.send(v, k) })
      end

      define_method :finalize, proc(&:all)

      def validate!
        raise ::Sequel::ValidationFailed, resource unless resource.valid?
      end
    end
  end
end
