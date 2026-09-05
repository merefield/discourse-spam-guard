# frozen_string_literal: true

module DiscourseSpamGuard
  class ReviewEvidence
    def self.preload(reviewables)
      reviews = reviewables.grep(ReviewableSpamGuard)
      scans = Scan.where(id: reviews.map { |review| review.payload["scan_id"] }).index_by(&:id)
      reviews.each do |review|
        scan = scans[review.payload["scan_id"]]
        scan.association(:user).target = review.target if scan
        review.spam_guard_scan = scan
      end
    end
  end
end
