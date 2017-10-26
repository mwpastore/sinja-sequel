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
          c.validation_formatter = proc do |e|
            e.errors.keys.each do |column|
              if assocs = e.model.class.autoreloading_associations[column]
                # copy errors attached to a FK column to the relevant association
                assocs.each do |assoc|
                  e.errors[assoc] = e.errors[column]
                end

                e.errors.delete(column)
              end
            end

            typeof = e.model.class.associations
              .map { |k| [k, :relationships] }.to_h
              .tap { |h| h.default = :attributes }

            e.errors.flat_map do |ee|
              next [[nil, ee]] if ee.is_a?(::Sequel::LiteralString)

              key, messages = *ee
              Array(messages).map do |message|
                [key, "#{key} #{message}", typeof[key]]
              end
            end
          end
        end

        base.prepend(Pagination) if ::Sequel::Model.db.dataset.respond_to?(:paginate)
      end

      def self.included(_)
        abort "You must `prepend' Sinja::Sequel::Core, not `include' it!"
      end

      def_delegator ::Sequel::Model, :db, :database

      def_delegator :database, :transaction

      define_method :filter, &:where

      def sort(collection, fields)
        collection.order(*fields.map { |k, v| ::Sequel.send(v, k) })
      end

      define_method :finalize, &:all

      def validate!
        raise ::Sequel::ValidationFailed, resource unless resource.valid?
      end

      def serialize_linkage(*, **options)
        options[:skip_collection_check] = true
        super
      end

      def serialize_model(*, **options)
        options[:skip_collection_check] = true
        super
      end
    end
  end
end
