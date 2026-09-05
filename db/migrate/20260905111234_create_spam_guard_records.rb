# frozen_string_literal: true
class CreateSpamGuardRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :spam_guard_accounts do |t|
      t.bigint :user_id, null: false
      t.boolean :allowed, null: false, default: false
      t.bigint :allowed_by_id
      t.bigint :silence_history_id
      t.datetime :silenced_till
      t.timestamps
    end
    add_index :spam_guard_accounts, :user_id, unique: true
    create_table :spam_guard_scans do |t|
      t.bigint :user_id, null: false
      t.bigint :reviewable_id
      t.string :source, null: false
      t.string :status, null: false
      t.string :decision, null: false
      t.string :action_taken, null: false, default: "none"
      t.string :error_code
      t.jsonb :evidence, null: false, default: {}
      t.jsonb :policy, null: false, default: {}
      t.timestamps
    end
    add_index :spam_guard_scans, %i[user_id created_at]
    add_index :spam_guard_scans, :created_at
    add_index :spam_guard_scans, :reviewable_id
  end
end
