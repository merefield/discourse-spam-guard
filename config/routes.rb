# frozen_string_literal: true

Discourse::Application.routes.draw do
  scope "/admin/plugins/discourse-spam-guard", constraints: AdminConstraint.new do
    get "/activity" => "discourse_spam_guard/admin#index"
    post "/check" => "discourse_spam_guard/admin#check"
    post "/test" => "discourse_spam_guard/admin#test_connection"
    get "/accounts/:user_id" => "discourse_spam_guard/admin#account"
    get "/accounts/:user_id/submission" => "discourse_spam_guard/admin#submission"
    post "/accounts/:user_id/submission" => "discourse_spam_guard/admin#submit_report"
    put "/accounts/:user_id/exception" => "discourse_spam_guard/admin#update_exception"
  end
end
