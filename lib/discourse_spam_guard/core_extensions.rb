# frozen_string_literal: true

module DiscourseSpamGuard
  module CoreExtensions
    module AdminUsersController
      def serialize_data(object, serializer, options = nil)
        if serializer == AdminUserListSerializer
          DiscourseSpamGuard::AdminUserList.preload(object, guardian)
        end
        super
      end
    end

    module ReviewableQuery
      def list_for(*args, **options)
        result = super
        options.fetch(:preload, true) ? result.extending(ReviewableRelation) : result
      end
    end

    module ReviewableRelation
      def records
        super.tap { |reviews| DiscourseSpamGuard::ReviewEvidence.preload(reviews) }
      end
    end
  end
end
