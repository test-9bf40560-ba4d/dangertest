class AddLocationToMicrocosms < ActiveRecord::Migration[7.0]
  def change
    # This group of migrations for microcosms will be run together, so there
    # will be no records with null values.
    safety_assured do
      change_table :microcosms, :bulk => true do |t|
        t.string :location, :null => false
        t.float :latitude, :null => false
        t.float :longitude, :null => false
        t.float :min_lat, :null => false
        t.float :max_lat, :null => false
        t.float :min_lon, :null => false
        t.float :max_lon, :null => false
      end
    end
  end
end