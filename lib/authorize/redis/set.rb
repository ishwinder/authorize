module Authorize
  module Redis
    class Set < Base
      undef to_a # In older versions of Ruby, Object#to_a is invoked and #method_missing is never called.

      def valid?
        %w(none set).include?(db.type(id))
      end

      def add(v)
        db.sadd(id, v)
      end

      def <<(v)
        add(v)
      end

      def delete(v)
        db.srem(id, v)
      end

      def __getobj__
        db.smembers(id).to_set
      end

      def ==(other)
        eql?(other) || (__getobj__ == other.__getobj__)
      end
    end
  end
end