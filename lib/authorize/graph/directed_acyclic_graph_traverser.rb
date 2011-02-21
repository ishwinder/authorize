require 'authorize/redis'
require 'enumerator'

# Walk the graph and yield encountered vertices.  The graph is assumed to be acyclic and no cycle detection is performed
# unless the check parameter is true.  This algorithm uses recursive calls, so beware of heap/stack issues on deep graphs,
# and memory issues if the check option is used.
module Authorize
  module Graph
    class DirectedAcyclicGraphTraverser
      def self.traverse(start, check = false)
        self.new(check).traverse(start)
      end

      def initialize(check = false)
        @enumerator = check ? :traverse_safely : :_traverse
        reset!
      end

      def traverse(start)
        to_enum(@enumerator, start)
      end

      def reset!
        @odometer = 0
      end

      private
      def _traverse(start, &block)
        yield start
        start.edges.each do |e|
          @odometer += 1
          _traverse(e.to, &block)
        end
        @odometer
      end

      def traverse_safely(start, &block)
        seen = ::Set.new
        _traverse(start) do |vertex|
          raise "Cycle detected at #{vertex} (Odometer at #{@odometer})!" if seen.include?(vertex)
          seen << vertex
          yield vertex
        end.tap {seen = nil}
      end
    end
  end
end