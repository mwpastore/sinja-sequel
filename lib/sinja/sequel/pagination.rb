# frozen_string_literal: true
module Sinja
  module Sequel
    module Pagination
      def self.prepended(base)
        base.sinja { |c| c.page_using = {
          :number=>1,
          :size=>10,
          :record_count=>nil
        }}
      end

      def self.included(_)
        abort "You must `prepend' Sinja::Sequel::Pagination, not `include' it!"
      end

      def page(collection, opts)
        return collection, {} unless collection.respond_to?(:paginate) ||
          collection.respond_to?(:dataset) && (collection = collection.dataset).respond_to?(:paginate)

        opts = settings._sinja.page_using.merge(opts)
        collection = collection.paginate \
          opts[:number].to_i,
          opts[:size].to_i,
          (opts[:record_count].to_i if opts[:record_count])

        # Attributes common to all pagination links
        base = {
          :size=>collection.page_size,
          :record_count=>collection.pagination_record_count
        }

        pagination = {
          :first=>base.merge(:number=>1),
          :self=>base.merge(:number=>collection.current_page),
          :last=>base.merge(:number=>collection.page_count)
        }
        pagination[:next] = base.merge(:number=>collection.next_page) if collection.next_page
        pagination[:prev] = base.merge(:number=>collection.prev_page) if collection.prev_page

        return collection, pagination
      end
    end
  end
end
