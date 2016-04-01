module WarRoom
  module ArrayRefinements
    refine Array do

      # @overload insert(index, *obj)
      #   Inserts the given values before the element with the given index.
      #   @param [Integer] index
      #   @param [Object] obj...
      #   @return [Array]
      #   @see Array#insert
      # @overload insert(*obj, &block)
      #   Inserts the given values before the first element for which the block
      #   returns true.
      #   @param [Object] obj...
      #   @yield [x]
      #   @yieldreturn [true|false]
      #   @return [Array]
      def insert(*args, &block)
        if block_given?
          insert(find_index(&block), *args)
        else
          super
        end
      end
    end
  end
end
