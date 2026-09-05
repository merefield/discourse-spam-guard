# frozen_string_literal: true
class AddSpamGuardScanLookupIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :spam_guard_scans,
                 name: "idx_spam_guard_scans_latest",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :spam_guard_scans,
              %i[user_id created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              name: "idx_spam_guard_scans_latest",
              algorithm: :concurrently
    remove_index :spam_guard_scans,
                 name: "idx_spam_guard_scans_source_latest",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :spam_guard_scans,
              %i[user_id source created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              name: "idx_spam_guard_scans_source_latest",
              algorithm: :concurrently
  end

  def down
    remove_index :spam_guard_scans,
                 name: "idx_spam_guard_scans_source_latest",
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :spam_guard_scans,
                 name: "idx_spam_guard_scans_latest",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
