# frozen_string_literal: true

class AddWorkingLanguagesToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :working_languages, :json, null: false, default: []
  end
end
