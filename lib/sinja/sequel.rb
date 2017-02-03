# frozen_string_literal: true
require 'sinja/sequel/helpers'
require 'sinja/sequel/version'

module Sinja
  module Sequel
    def self.registered(app)
      app.helpers Helpers
    end

    def resource(res, try_convert=:to_i, &block)
      klass = res.to_s.classify.constantize

      super(res) do
        register Resource

        helpers do
          define_method(:dataset) do
            klass.dataset
          end

          define_method(:find) do |id|
            dataset[id.send(try_convert)]
          end
        end

        show

        show_many do |ids|
          dataset.where(klass.primary_key=>ids.map!(&try_convert)).all
        end

        index do
          dataset
        end

        create do |attr|
          tmp = klass.new
          if respond_to?(:settable_fields)
            tmp.set_fields(attr, settable_fields)
          else
            tmp.set(attr)
          end
          tmp.save(:validate=>false)
          next_pk tmp
        end

        update do |attr|
          if respond_to?(:settable_fields)
            resource.update_fields(attr, settable_fields, :validate=>false, :missing=>:skip)
          else
            resource.set(attr)
            resource.save_changes(:validate=>false)
          end
        end

        destroy do
          resource.destroy
        end

        instance_eval(&block) if block
      end
    end

    module Resource
      def has_one(rel, try_convert=:to_i, &block)
        super(rel) do
          pluck do
            resource.send(rel)
          end

          prune(:sideload_on=>:update) do
            resource.send("#{rel}=", nil)
            resource.save_changes
          end

          graft(:sideload_on=>%i[create update]) do |rio|
            klass = resource.class.association_reflection(rel).associated_class
            resource.send("#{rel}=", klass.with_pk!(rio[:id].send(try_convert)))
            resource.save_changes(:validate=>!sideloaded?)
          end

          instance_eval(&block) if block
        end
      end

      def has_many(rel, try_convert=:to_i, &block)
        super(rel) do
          fetch do
            resource.send("#{rel}_dataset")
          end

          clear(:sideload_on=>:update) do
            resource.send("remove_all_#{rel}")
          end

          replace(:sideload_on=>:update) do |rios|
            add_remove(rel, rios, try_convert)
          end

          merge(:sideload_on=>:create) do |rios|
            add_missing(rel, rios, try_convert)
          end

          subtract do |rios|
            remove_present(rel, rios, try_convert)
          end

          instance_eval(&block) if block
        end
      end
    end
  end
end
