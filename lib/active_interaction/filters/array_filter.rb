# frozen_string_literal: true

module ActiveInteraction
  class Base
    # @!method self.array(*attributes, options = {}, &block)
    #   Creates accessors for the attributes and ensures that values passed to
    #     the attributes are Arrays.
    #
    #   @!macro filter_method_params
    #   @param block [Proc] filter method to apply to each element
    #
    #   @example
    #     array :ids
    #   @example
    #     array :ids do
    #       integer
    #     end
    #   @example
    #     array :ids do
    #       integer default: nil
    #     end
  end

  # @private
  class ArrayFilter < Filter
    include Missable

    register :array

    private

    def klasses
      %w[
        ActiveRecord::Relation
        ActiveRecord::Associations::CollectionProxy
      ].each_with_object([Array]) do |name, result|
        next unless (klass = name.safe_constantize)

        result.push(klass)
      end
    end

    def matches?(value)
      klasses.any? { |klass| value.is_a?(klass) }
    end

    def adjust_output(value, context)
      return value if filters.empty?

      filter = filters.values.first
      value.map { |e| filter.clean(e, context) }
    end

    def convert(value)
      if value.respond_to?(:to_ary)
        value.to_ary
      else
        value
      end
    end

    # rubocop:disable Metrics/AbcSize, Style/MissingRespondToMissing
    def method_missing(*, &block)
      super do |klass, names, options|
        if klass == ObjectFilter && !options.key?(:class)
          options[:class] = name.to_s.singularize.camelize.to_sym
        end

        filter = klass.new(names.first || '', options, &block)

        filters[filters.size.to_s.to_sym] = filter

        validate!(filter, names)
      end
    end
    # rubocop:enable Metrics/AbcSize, Style/MissingRespondToMissing

    # @param filter [Filter]
    # @param names [Array<Symbol>]
    #
    # @raise [InvalidFilterError]
    def validate!(filter, names)
      if filters.size > 1
        raise InvalidFilterError, 'multiple filters in array block'
      end

      unless names.empty?
        raise InvalidFilterError, 'attribute names in array block'
      end

      if filter.default?
        raise InvalidDefaultError, 'default values in array block'
      end

      nil
    end
  end
end
