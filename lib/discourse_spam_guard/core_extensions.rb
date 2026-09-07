# frozen_string_literal: true

module DiscourseSpamGuard
  module CoreExtensions
    module FlaggedPost
      attr_writer :spam_guard_scan, :spam_guard_ai_review

      def spam_guard_scan
        return @spam_guard_scan if defined?(@spam_guard_scan)
        @spam_guard_scan = DiscourseSpamGuard::Scan.where(reviewable_id: id).latest.first
      end

      def spam_guard_ai_review?
        return @spam_guard_ai_review if defined?(@spam_guard_ai_review)
        @spam_guard_ai_review = DiscourseSpamGuard::AiIntegration.ai_review_ids([self]).include?(id)
      end
    end

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
