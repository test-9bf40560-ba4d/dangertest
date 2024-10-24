require "test_helper"

class NoteTest < ActiveSupport::TestCase
  def test_status_valid
    ok = %w[open closed hidden]
    bad = %w[expropriated fubared]

    ok.each do |status|
      note = create(:note)
      note.status = status
      assert_predicate note, :valid?, "#{status} is invalid, when it should be"
    end

    bad.each do |status|
      note = create(:note)
      note.status = status
      assert_not_predicate note, :valid?, "#{status} is valid when it shouldn't be"
    end
  end

  def test_body_valid
    ok = %W[Name vergrößern foo\nbar
            ルシステムにも対応します 輕觸搖晃的遊戲]
    bad = ["foo\x00bar", "foo\x08bar", "foo\x1fbar", "foo\x7fbar",
           "foo\ufffebar", "foo\uffffbar"]

    ok.each do |body|
      note = build(:note, :body => body)
      assert_predicate note, :valid?, "#{body} is invalid, when it should be"
    end

    bad.each do |body|
      note = build(:note, :body => body)
      assert_not note.valid?, "#{body} is valid when it shouldn't be"
    end
  end

  def test_close
    note = create(:note)
    assert_equal "open", note.status
    assert_nil note.closed_at
    note.close
    assert_equal "closed", note.status
    assert_not_nil note.closed_at
  end

  def test_reopen
    note = create(:note, :closed)
    assert_equal "closed", note.status
    assert_not_nil note.closed_at
    note.reopen
    assert_equal "open", note.status
    assert_nil note.closed_at
  end

  def test_visible?
    assert_predicate create(:note, :status => "open"), :visible?
    assert_predicate create(:note, :closed), :visible?
    assert_not_predicate create(:note, :status => "hidden"), :visible?
  end

  def test_closed?
    assert_predicate create(:note, :closed), :closed?
    assert_not_predicate create(:note, :status => "open", :closed_at => nil), :closed?
  end

  # FIXME: notes_refactoring
  def test_author_from_opened_note_comment
    note = create(:note, :author => nil, :body => nil)
    comment = create(:note_comment, :note => note, :event => "opened", :author => create(:user))
    assert_equal comment.author, note.reload.author
  end

  def test_author
    note = create(:note)
    assert_nil note.author

    user = create(:user)
    note = create(:note, :author => user)
    assert_equal user, note.author
  end

  def test_api_comments_before_migration
    note = create(:note, :body => nil)
    create(:note_comment, :note => note, :event => "opened", :body => note.body)
    create(:note_comment, :note => note, :event => "commented")

    assert_equal %w[opened commented], note.reload.api_comments.pluck(:event)
  end

  def test_api_comments_before_deletion_of_first_comment
    note = create(:note, :body => "Hello")
    create(:note_comment, :note => note, :event => "opened", :body => note.body)
    create(:note_comment, :note => note, :event => "commented")

    assert_equal %w[opened commented], note.reload.api_comments.pluck(:event)
  end

  def test_api_comments_after_deletion_of_first_comment
    note = create(:note)
    create(:note_comment, :note => note, :event => "commented", :author => create(:user))

    assert_equal %w[opened commented], note.reload.api_comments.pluck(:event)
  end

  # FIXME: notes_refactoring
  def test_author_ip_from_opened_note_comment
    note = create(:note, :author_ip => nil, :body => nil)
    create(:note_comment, :note => note, :event => "opened", :author_ip => "192.168.1.1")
    assert_equal IPAddr.new("192.168.1.1"), note.reload.author_ip
  end

  def test_author_ip
    note = create(:note)
    assert_nil note.author_ip

    note = create(:note, :author_ip => IPAddr.new("192.168.1.1"))
    assert_equal IPAddr.new("192.168.1.1"), note.author_ip
  end

  # Ensure the lat/lon is formatted as a decimal e.g. not 4.0e-05
  def test_lat_lon_format
    note = build(:note, :latitude => 0.00004 * GeoRecord::SCALE, :longitude => 0.00008 * GeoRecord::SCALE)

    assert_equal "0.0000400", note.lat.to_s
    assert_equal "0.0000800", note.lon.to_s
  end
end
