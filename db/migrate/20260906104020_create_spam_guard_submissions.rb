# frozen_string_literal: true

class CreateSpamGuardSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :spam_guard_submissions do |t|
      t.bigint :user_id, null: false
      t.bigint :actor_id, null: false
      t.bigint :post_id, null: false
      t.bigint :reviewable_id, null: false
      t.string :fingerprint, null: false, limit: 64
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :approved_at, null: false
      t.datetime :last_attempt_at
      t.datetime :completed_at
      t.string :error_code
      t.jsonb :events, null: false, default: []
      t.timestamps
    end
    add_index :spam_guard_submissions, :user_id, unique: true
    add_index :spam_guard_submissions, %i[status updated_at]
  end
end
