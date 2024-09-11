require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  ##
  # test all routes which lead to this controller
  def test_routes
    assert_routing(
      { :path => "/user/new", :method => :get },
      { :controller => "users", :action => "new" }
    )

    assert_routing(
      { :path => "/user/new", :method => :post },
      { :controller => "users", :action => "create" }
    )

    assert_routing(
      { :path => "/user/terms", :method => :get },
      { :controller => "users", :action => "terms" }
    )

    assert_routing(
      { :path => "/user/save", :method => :post },
      { :controller => "users", :action => "save" }
    )

    assert_routing(
      { :path => "/user/go_public", :method => :post },
      { :controller => "users", :action => "go_public" }
    )

    assert_routing(
      { :path => "/user/suspended", :method => :get },
      { :controller => "users", :action => "suspended" }
    )

    assert_routing(
      { :path => "/user/username", :method => :get },
      { :controller => "users", :action => "show", :display_name => "username" }
    )

    assert_routing(
      { :path => "/user/username/set_status", :method => :post },
      { :controller => "users", :action => "set_status", :display_name => "username" }
    )
    assert_routing(
      { :path => "/user/username", :method => :delete },
      { :controller => "users", :action => "destroy", :display_name => "username" }
    )
  end

  # The user creation page loads
  def test_new_view
    get user_new_path
    assert_redirected_to user_new_path(:cookie_test => "true")

    get user_new_path, :params => { :cookie_test => "true" }
    assert_response :success

    assert_select "html", :count => 1 do
      assert_select "head", :count => 1 do
        assert_select "title", :text => /Sign Up/, :count => 1
      end
      assert_select "body", :count => 1 do
        assert_select "div#content", :count => 1 do
          assert_select "form[action='/user/new'][method='post']", :count => 1 do
            assert_select "input[id='user_email']", :count => 1
            assert_select "input[id='user_display_name']", :count => 1
            assert_select "input[id='user_pass_crypt'][type='password']", :count => 1
            assert_select "input[id='user_pass_crypt_confirmation'][type='password']", :count => 1
            assert_select "input[type='submit'][value='Sign Up']", :count => 1
          end
        end
      end
    end
  end

  def test_new_view_logged_in
    session_for(create(:user))

    get user_new_path
    assert_redirected_to root_path

    get user_new_path, :params => { :referer => "/test" }
    assert_redirected_to "/test"
  end

  def test_new_success
    user = build(:user, :pending)

    assert_difference "User.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        perform_enqueued_jobs do
          post user_new_path, :params => { :user => user.attributes }
        end
      end
    end

    # Check the e-mail
    register_email = ActionMailer::Base.deliveries.first

    assert_equal register_email.to[0], user.email
    assert_match(/#{@url}/, register_email.body.to_s)

    # Check the page
    assert_redirected_to :controller => :confirmations, :action => :confirm, :display_name => user.display_name

    ActionMailer::Base.deliveries.clear
  end

  def test_new_duplicate_email
    user = build(:user, :pending)
    create(:user, :email => user.email)

    assert_no_difference "User.count" do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        perform_enqueued_jobs do
          post user_new_path, :params => { :user => user.attributes }
        end
      end
    end

    assert_response :success
    assert_template "new"
    assert_select "form > div > input.is-invalid#user_email"
  end

  def test_new_duplicate_email_uppercase
    user = build(:user, :pending)
    create(:user, :email => user.email.upcase)

    assert_no_difference "User.count" do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        perform_enqueued_jobs do
          post user_new_path, :params => { :user => user.attributes }
        end
      end
    end

    assert_response :success
    assert_template "new"
    assert_select "form > div > input.is-invalid#user_email"
  end

  def test_new_duplicate_name
    user = build(:user, :pending)
    create(:user, :display_name => user.display_name)

    assert_no_difference "User.count" do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        perform_enqueued_jobs do
          post user_new_path, :params => { :user => user.attributes }
        end
      end
    end

    assert_response :success
    assert_template "new"
    assert_select "form > div > input.is-invalid#user_display_name"
  end

  def test_new_duplicate_name_uppercase
    user = build(:user, :pending)
    create(:user, :display_name => user.display_name.upcase)

    assert_no_difference "User.count" do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        perform_enqueued_jobs do
          post user_new_path, :params => { :user => user.attributes }
        end
      end
    end

    assert_response :success
    assert_template "new"
    assert_select "form > div > input.is-invalid#user_display_name"
  end

  def test_new_blocked_domain
    user = build(:user, :pending, :email => "user@example.net")

    # Now block that domain
    create(:acl, :domain => "example.net", :k => "no_account_creation")

    # Check that the second half of registration fails
    assert_no_difference "User.count" do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        perform_enqueued_jobs do
          post user_new_path, :params => { :user => user.attributes }
        end
      end
    end

    assert_response :success
    assert_template "blocked"
  end

  def test_save_referer_params
    user = build(:user, :pending)

    assert_difference "User.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        post user_new_path, :params => { :user => user.attributes, :referer => "/edit?editor=id#map=1/2/3" }
        assert_enqueued_with :job => ActionMailer::MailDeliveryJob,
                             :args => proc { |args| args[3][:args][2] == welcome_path(:editor => "id", :zoom => 1, :lat => 2, :lon => 3) }
        perform_enqueued_jobs
      end
    end

    ActionMailer::Base.deliveries.clear
  end

  def test_terms_agreed
    user = create(:user, :terms_seen => true, :terms_agreed => Date.yesterday)

    session_for(user)

    get user_terms_path
    assert_redirected_to edit_account_path
  end

  def test_terms_not_seen_without_referer
    user = create(:user, :terms_seen => false, :terms_agreed => nil)

    session_for(user)

    get user_terms_path
    assert_response :success
    assert_template :terms

    post user_save_path, :params => { :user => { :consider_pd => true }, :read_ct => 1, :read_tou => 1 }
    assert_redirected_to edit_account_path
    assert_equal "Thanks for accepting the new contributor terms!", flash[:notice]

    user.reload

    assert user.consider_pd
    assert_not_nil user.terms_agreed
    assert user.terms_seen
  end

  def test_terms_not_seen_with_referer
    user = create(:user, :terms_seen => false, :terms_agreed => nil)

    session_for(user)

    get user_terms_path, :params => { :referer => "/test" }
    assert_response :success
    assert_template :terms

    post user_save_path, :params => { :user => { :consider_pd => true }, :referer => "/test", :read_ct => 1, :read_tou => 1 }
    assert_redirected_to "/test"
    assert_equal "Thanks for accepting the new contributor terms!", flash[:notice]

    user.reload

    assert user.consider_pd
    assert_not_nil user.terms_agreed
    assert user.terms_seen
  end

  # Check that if you haven't seen the terms, and make a request that requires authentication,
  # that your request is redirected to view the terms
  def test_terms_not_seen_redirection
    user = create(:user, :terms_seen => false, :terms_agreed => nil)
    session_for(user)

    get edit_account_path
    assert_redirected_to :controller => :users, :action => :terms, :referer => "/account/edit"
  end

  def test_terms_not_logged_in
    get user_terms_path

    assert_redirected_to login_path(:referer => "/user/terms")
  end

  def test_go_public
    user = create(:user, :data_public => false)
    session_for(user)

    post user_go_public_path

    assert_redirected_to edit_account_path
    assert User.find(user.id).data_public
  end

  # Check that the user account page will display and contains some relevant
  # information for the user
  def test_show
    # Test a non-existent user
    get user_path("unknown")
    assert_response :not_found

    # Test a normal user
    user = create(:user)

    get user_path(user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "a[href^='/user/#{ERB::Util.u(user.display_name)}/history']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/traces']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/diary']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/diary/comments']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/account']", 0
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/blocks']", 0
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/blocks_by']", 0
      assert_select "a[href='/blocks/new/#{ERB::Util.u(user.display_name)}']", 0
    end

    # Test a user who has been blocked
    blocked_user = create(:user)
    create(:user_block, :user => blocked_user)
    get user_path(blocked_user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "a[href^='/user/#{ERB::Util.u(blocked_user.display_name)}/history']", 1
      assert_select "a[href='/user/#{ERB::Util.u(blocked_user.display_name)}/traces']", 1
      assert_select "a[href='/user/#{ERB::Util.u(blocked_user.display_name)}/diary']", 1
      assert_select "a[href='/user/#{ERB::Util.u(blocked_user.display_name)}/diary/comments']", 1
      assert_select "a[href='/user/#{ERB::Util.u(blocked_user.display_name)}/account']", 0
      assert_select "a[href='/user/#{ERB::Util.u(blocked_user.display_name)}/blocks']", 1
      assert_select "a[href='/user/#{ERB::Util.u(blocked_user.display_name)}/blocks_by']", 0
      assert_select "a[href='/blocks/new/#{ERB::Util.u(blocked_user.display_name)}']", 0
    end

    # Test a moderator who has applied blocks
    moderator_user = create(:moderator_user)
    create(:user_block, :creator => moderator_user)
    get user_path(moderator_user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "a[href^='/user/#{ERB::Util.u(moderator_user.display_name)}/history']", 1
      assert_select "a[href='/user/#{ERB::Util.u(moderator_user.display_name)}/traces']", 1
      assert_select "a[href='/user/#{ERB::Util.u(moderator_user.display_name)}/diary']", 1
      assert_select "a[href='/user/#{ERB::Util.u(moderator_user.display_name)}/diary/comments']", 1
      assert_select "a[href='/user/#{ERB::Util.u(moderator_user.display_name)}/account']", 0
      assert_select "a[href='/user/#{ERB::Util.u(moderator_user.display_name)}/blocks']", 0
      assert_select "a[href='/user/#{ERB::Util.u(moderator_user.display_name)}/blocks_by']", 1
      assert_select "a[href='/blocks/new/#{ERB::Util.u(moderator_user.display_name)}']", 0
    end

    # Login as a normal user
    session_for(user)

    # Test the normal user
    get user_path(user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "a[href^='/user/#{ERB::Util.u(user.display_name)}/history']", 1
      assert_select "a[href='/traces/mine']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/diary']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/diary/comments']", 1
      assert_select "a[href='/account/edit']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/blocks']", 0
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/blocks_by']", 0
      assert_select "a[href='/blocks/new/#{ERB::Util.u(user.display_name)}']", 0
      assert_select "a[href='/api/0.6/user/#{ERB::Util.u(user.id)}']", 0
    end

    # Login as a moderator
    session_for(create(:moderator_user))

    # Test the normal user
    get user_path(user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "a[href^='/user/#{ERB::Util.u(user.display_name)}/history']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/traces']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/diary']", 1
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/diary/comments']", 1
      assert_select "a[href='/account/edit']", 0
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/blocks']", 0
      assert_select "a[href='/user/#{ERB::Util.u(user.display_name)}/blocks_by']", 0
      assert_select "a[href='/blocks/new/#{ERB::Util.u(user.display_name)}']", 1
      assert_select "a[href='/api/0.6/user/#{ERB::Util.u(user.id)}']", 1
    end
  end

  # Test whether information about contributor terms is shown for users who haven't agreed
  def test_terms_not_agreed
    agreed_user = create(:user, :terms_agreed => 3.days.ago)
    seen_user = create(:user, :terms_seen => true, :terms_agreed => nil)
    not_seen_user = create(:user, :terms_seen => false, :terms_agreed => nil)

    get user_path(agreed_user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "dt", :count => 0, :text => /Contributor terms/
    end

    get user_path(seen_user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "dt", :count => 1, :text => /Contributor terms/
      assert_select "dd", /Declined/
    end

    get user_path(not_seen_user)
    assert_response :success
    assert_select "div.content-heading" do
      assert_select "dt", :count => 1, :text => /Contributor terms/
      assert_select "dd", /Undecided/
    end
  end

  def test_set_status
    user = create(:user)

    # Try without logging in
    post set_status_user_path(user), :params => { :event => "confirm" }
    assert_response :forbidden

    # Now try as a normal user
    session_for(user)
    post set_status_user_path(user), :params => { :event => "confirm" }
    assert_redirected_to :controller => :errors, :action => :forbidden

    # Finally try as an administrator
    session_for(create(:administrator_user))
    post set_status_user_path(user), :params => { :event => "confirm" }
    assert_redirected_to :action => :show, :display_name => user.display_name
    assert_equal "confirmed", User.find(user.id).status
  end

  def test_destroy
    user = create(:user, :home_lat => 12.1, :home_lon => 12.1, :description => "test")

    # Try without logging in
    delete user_path(user)
    assert_response :forbidden

    # Now try as a normal user
    session_for(user)
    delete user_path(user)
    assert_redirected_to :controller => :errors, :action => :forbidden

    # Finally try as an administrator
    session_for(create(:administrator_user))
    delete user_path(user)
    assert_redirected_to :action => :show, :display_name => user.display_name

    # Check that the user was deleted properly
    user.reload
    assert_equal "user_#{user.id}", user.display_name
    assert_equal "", user.description
    assert_nil user.home_lat
    assert_nil user.home_lon
    assert_not user.avatar.attached?
    assert_not user.email_valid
    assert_nil user.new_email
    assert_nil user.auth_provider
    assert_nil user.auth_uid
    assert_equal "deleted", user.status
  end

  def test_auth_failure_callback
    get auth_failure_path
    assert_redirected_to login_path

    get auth_failure_path, :params => { :origin => "/" }
    assert_redirected_to root_path

    get auth_failure_path, :params => { :origin => "http://www.google.com" }
    assert_redirected_to login_path
  end
end
