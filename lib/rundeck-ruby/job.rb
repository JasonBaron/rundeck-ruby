module Rundeck
  class Job

    def self.find(session, id)
      result = session.get("api/1/job/#{id}", 'joblist', 'job')
      return nil unless result
      project = Project.find(session, result['context']['project'])
      return nil unless project
      Job.new(session, project, result['id'], result['name'])
    end

    def self.from_hash(session, hash)
      project = Project.find(session, hash['project'])
      new(session, project, hash['id'], hash['name'])
    end

    def initialize(session, project, id, name)
      @session = session
      @project = project
      @id = id
      @name = name
    end

    attr_reader :id, :name, :project, :session

    def executions
      qb = JobExecutionQueryBuilder.new
      yield qb if block_given?

      endpoint = "api/1/job/#{id}/executions#{qb.query}"
      results = session.get(endpoint, 'result', 'executions', 'execution') || []
      results = [results] if results.is_a?(Hash) #Work around an inconsistency in the API
      results.map{|hash| Execution.from_hash(session, hash)}
    end

    def execute!(query_string = '')
      query = "api/1/job/#{id}/run?#{query_string}".chomp("?")
      hash = session.get(query, 'result', 'executions', 'execution') || {}
      Execution.new(session, hash, self)
    end

    class JobExecutionQueryBuilder
      attr_accessor :status, :max, :offset

      def self.valid_statuses
        Execution::QueryBuilder.valid_statuses
      end

      class ValidationError < StandardError
        def initialize(field, value, message=nil)
          msg = "Invalid #{field}: #{value}"
          msg += message unless message==nil
          super(msg)
        end
      end

      def validate
        raise ValidationError.new("status", status) unless status.nil? || self.class.valid_statuses.include?(status.to_s)
        raise ValidationError.new("offset", offset) unless offset.nil? || offset.to_i >= 0
        raise ValidationError.new("max", max) unless max.nil? || max.to_i >= 0
      end

      def query
        validate

        clauses = [
          status && "status=#{status}",
          max && "max=#{max.to_i}",
          offset && "offset=#{offset.to_i}",
        ].compact.join('&')

        "?#{clauses}".chomp('?')
      end
    end
  end
end
