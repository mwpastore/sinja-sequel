# frozen_string_literal: true
require 'sinja/sequel/helpers'
require 'sinja/sequel/version'

module Sinja
  module Sequel
    def self.registered(app)
      app.helpers Helpers
    end

    def sequel_resource(res, try_convert=:to_i, **opts, &block)
      klass = opts.fetch(:class) { res.to_s.classify.constantize }

      resource(res, **opts) do
        register Resource

        helpers do
          define_method(:default_dataset) do
            klass.dataset
          end

          alias_method :dataset, :default_dataset

          define_method(:find) do |id|
            dataset.with_pk(proc(&try_convert).(id))
          end
        end

        show

        show_many do |ids|
          dataset.where_all(klass.primary_key=>ids.map!(&try_convert))
        end

        index do
          dataset
        end

        create do |attr|
          tmp = klass.new
          tmp.set(attr)
          tmp.save(:validate=>false)
          next_pk tmp
        end

        update do |attr|
          resource.set(attr)
          resource.save_changes(:validate=>false)
        end

        destroy do
          resource.destroy
        end

        instance_eval(&block) if block
      end
    end

    module Resource
      def sequel_has_one(rel, try_convert=:to_i, &block)
        has_one(rel) do
          pluck do
            resource.send(rel)
          end

          prune(:sideload_on=>:update) do
            resource.send("#{rel}=", nil)
            resource.save_changes(:validate=>!sideloaded?)
          end

          graft(:sideload_on=>%i[create update]) do |rio|
            klass = resource.class.association_reflection(rel).associated_class
            resource.send("#{rel}=", klass.with_pk!(proc(&try_convert).(rio[:id])))
            resource.save_changes(:validate=>!sideloaded?)
          end

          instance_eval(&block) if block
        end
      end

      def sequel_has_many(rel, try_convert=:to_i, &block)
        has_many(rel) do
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
