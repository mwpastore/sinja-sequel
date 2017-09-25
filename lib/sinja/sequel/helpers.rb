# frozen_string_literal: true
require 'sinja/sequel/core'

module Sinja
  module Sequel
    module Helpers
      def self.included(base)
        base.prepend(Core)
      end

      def next_pk(resource, opts={})
        [resource.pk, resource, opts]
      end

      def add_remove(association, rios, try_convert=:to_i, **filters, &block)
        meth_suffix = association.to_s.singularize
        add_meth = "add_#{meth_suffix}".to_sym
        remove_meth = "remove_#{meth_suffix}".to_sym

        if block
          filters[:add] ||= block
          filters[:remove] ||= block
        end

        dataset = resource.send("#{association}_dataset")
        klass = dataset.association_reflection.associated_class

        new_ids = rios.map { |rio| proc(&try_convert).(rio[:id]) }
        transaction do
          resource.lock!
          old_ids = dataset.select_map(klass.primary_key)
          ids_in_common = old_ids & new_ids

          (new_ids - ids_in_common).each do |id|
            subresource = klass.with_pk!(id)
            next if filters[:add] && !filters[:add].(subresource)
            resource.send(add_meth, subresource)
          end unless filters[:add] == :__SKIP__

          (old_ids - ids_in_common).each do |id|
            subresource = klass.with_pk!(id)
            next if filters[:remove] && !filters[:remove].(subresource)
            resource.send(remove_meth, subresource)
          end unless filters[:remove] == :__SKIP__

          resource.reload
        end
      end

      def add_missing(*args, &block)
        add_remove(*args, :add=>block, :remove=>:__SKIP__)
      end

      def remove_present(*args, &block)
        add_remove(*args, :add=>:__SKIP__, :remove=>block)
      end
    end
  end
end
