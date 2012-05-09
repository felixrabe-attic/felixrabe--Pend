#!/usr/bin/env jruby
# -*- coding: utf-8 -*-

# German homework description:

# Erstellen Sie eine Applikation zur Pendenzenverwaltung.

# Eine Pendenz besteht aus einem Datum, einer Beschreibung und einem Flag, das
# besagt, ob die Pendenz erledigt sei. Die Applikation soll in einer Tabelle die
# Pendenzen zeigen. Man kann Pendenzen einfügen, löschen und editieren.

# Verwenden Sie für das GUI eine JTable mit einem eigenen Tabellen-Model
# (TableModel).

# Entwerfen Sie die Applikation unter Berücksichtigung des MVC-Paradigmas.
# Insbesondere sollte es später möglich sein, einzelne Bestandteile der
# Applikation auszuwechseln.


# Model dependencies:
require 'gentledb'    # data storage:   GentleDB
require 'csv'         # data format:    CSV

# View dependencies:
require 'swing_dsl'   # user interface: Swing

# Internal dependencies:
require 'date'
require 'ostruct'


# Deal with csv module's crazyness - https://gist.github.com/2639448
class CSV
  def CSV.unparse array
    CSV.generate do |csv|
      array.each { |i| csv << i }
    end
  end
end


class DataStorage
  PTR_ID = "eb221d123991ff2c85384203ee7d8c847d9fd5bb242660b721bf12ae4117a3b1"
  EMPTY = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  DEFAULT = "c6d963c99da92d0ca82ad59a30d7aea63cb85a5997b946ec3831022124b9be15"

  def initialize
    @gentledb = GentleDB::FS.new
  end

  def load content_id=nil
    content_id ||= @gentledb[PTR_ID]
    content_id = DEFAULT if content_id == EMPTY  # nothing to load, load default
    content = @gentledb - content_id
    previous_id, csv_string = content.split("\n", 2)
    data = CSV.parse(csv_string).map { |i| [i[0], i[1], i[2] != "false"] }
    return previous_id, content_id, data
  end

  def save content_id, data
    csv_string = CSV.unparse data
    new_content_id = @gentledb + "#{content_id}\n#{csv_string}"
    @gentledb[PTR_ID] = new_content_id
    return content_id, new_content_id
  end
end


class TODOListModel < javax.swing.table.AbstractTableModel
  def initialize storage
    super()
    @storage = storage
    @previous_id, @content_id, @data = @storage.load
    add_table_model_listener do |e|
      @previous_id, @content_id = @storage.save @content_id, @data
    end
  end

  def add
    @data << [(Time.new.to_date + 7).to_s, "", false]
    fire_table_rows_inserted @data.size-1, @data.size-1
  end

  def delete index
    @data[index..index] = []
    fire_table_rows_deleted index, index
  end

  def undo
    @previous_id, @content_id, @data = @storage.load @previous_id
    fire_table_data_changed
  end

  def getColumnName col
    %w(Date Description Done)[col]
  end

  def getColumnClass col
    col == 2 ? java.lang.Boolean.java_class : java.lang.String.java_class;
  end

  def getColumnCount ; 3 ; end

  def getRowCount
    @data.length
  end

  def getValueAt row, col
    @data[row][col]
  end

  def isCellEditable row, col
    true
  end

  def setValueAt value, row, col
    @data[row][col] = value
    fire_table_cell_updated row, col
  end
end


class TODOListController
  def initialize model
    @model = model
  end

  def add
    @model.add
  end

  def delete index
    @model.delete index
  end

  def undo
    @model.undo
  end
end


class SwingView
  def initialize model, controller
    @_ = OpenStruct.new
    @model = model
    @controller = controller
    build_gui
    observe @model
  end

  def message msg
    javax.swing.JOptionPane.showMessageDialog @_.frame.j, msg
  end

  def build_gui
    _ = @_
    view = self
    controller = @controller
    _.frame = SwingDSL::Frame "Pend" do
      content do
        to :north do
          panel do
            button "Add" do
              controller.add
            end
            button "Delete" do
              _.table.selected_rows.each { |i| controller.delete i }
            end
            button "Undo" do
              controller.undo
            end
          end
        end
        scroll_pane do
          _.table = table fills_viewport_height: true
        end
      end
    end
  end

  def observe model
    @_.table.model = model
  end
end


if __FILE__ == $0
  storage = DataStorage.new
  model = TODOListModel.new storage
  controller = TODOListController.new model
  view = SwingView.new model, controller
end
