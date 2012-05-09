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
require 'ostruct'


# Deal with csv module's crazyness - https://gist.github.com/2639448
class CSV
  def CSV.unparse array
    CSV.generate do |csv|
      array.each { |i| csv << i }
    end
  end
end


class TODOList < javax.swing.table.AbstractTableModel
  def initialize
    super
    @g = GentleDB::FS.new
    _load_from @g
  end

  def close
    # TODO: make sure this code gets called
    _store_to @g
  end

  def csv= csv_string
    @data = CSV.parse(csv_string).map { |i| [i[0], i[1], i[2] != "false"] }
  end

  def csv
    CSV.unparse @data
  end

  # TableModel interface

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

  private

  PTR_ID = "eb221d123991ff2c85384203ee7d8c847d9fd5bb242660b721bf12ae4117a3b1"

  def _load_from g
    self.csv = g - g[PTR_ID]
  end

  def _store_to g
    g[PTR_ID] = g + self.csv
  end
end


class View
  def initialize model
    @model = model
    observe @model
  end

  def observe model
    # TODO: Observe model
  end
end


class SwingView < View
  def initialize model
    @_ = OpenStruct.new
    build_gui
    super
  end

  def build_gui
    _ = @_
    SwingDSL::Frame "Pend" do
      content do
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


class Pend
  def initialize
    @model = TODOList.new
    @view = SwingView.new @model
  end
end


if __FILE__ == $0
  Pend.new
end
