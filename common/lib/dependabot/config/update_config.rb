# typed: true
# frozen_string_literal: true

require "dependabot/config/ignore_condition"
require "sorbet-runtime"

module Dependabot
  module Config
    # Configuration for a single ecosystem
    class UpdateConfig
      extend T::Sig

      sig { returns(T.nilable(CommitMessageOptions)) }
      attr_reader :commit_message_options

      sig { returns(T::Array[IgnoreCondition]) }
      attr_reader :ignore_conditions

      sig do
        params(
          ignore_conditions: T.nilable(T::Array[IgnoreCondition]),
          commit_message_options: T.nilable(CommitMessageOptions)
        ).void
      end
      def initialize(ignore_conditions: nil, commit_message_options: nil)
        @ignore_conditions = ignore_conditions || []
        @commit_message_options = commit_message_options
      end

      sig { params(dependency: Dependency, security_updates_only: T::Boolean).returns(T::Array[String]) }
      def ignored_versions_for(dependency, security_updates_only: false)
        normalizer = name_normaliser_for(dependency)
        dep_name = normalizer.call(dependency.name)

        @ignore_conditions
          .select { |ic| self.class.wildcard_match?(normalizer.call(ic.dependency_name), dep_name) }
          .map { |ic| ic.ignored_versions(dependency, security_updates_only) }
          .flatten
          .compact
          .uniq
      end

      sig { params(wildcard_string: T.nilable(String), candidate_string: T.nilable(String)).returns(T::Boolean) }
      def self.wildcard_match?(wildcard_string, candidate_string)
        return false unless wildcard_string && candidate_string

        regex_string = "a#{wildcard_string.downcase}a".split("*")
                                                      .map { |p| Regexp.quote(p) }
                                                      .join(".*").gsub(/^a|a$/, "")
        regex = /^#{regex_string}$/
        regex.match?(candidate_string.downcase)
      end

      private

      def name_normaliser_for(dep)
        name_normaliser ||= {}
        name_normaliser[dep] ||= Dependency.name_normaliser_for_package_manager(dep.package_manager)
      end

      class CommitMessageOptions
        extend T::Sig

        attr_reader :prefix, :prefix_development, :include

        def initialize(prefix:, prefix_development:, include:)
          @prefix = prefix
          @prefix_development = prefix_development
          @include = include
        end

        def include_scope?
          @include == "scope"
        end

        def to_h
          {
            prefix: @prefix,
            prefix_development: @prefix_development,
            include_scope: include_scope?
          }
        end
      end
    end
  end
end
