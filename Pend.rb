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

require 'swing_dsl'
require 'gentledb'


class TODOList < javax.swing.table.AbstractTableModel
  def initialize
    # Load from GentleDB
  end

  def close
    # Store into GentleDB
  end
end


class Pend
  def initialize
    # Set up the application
  end
end


if __FILE__ == $0
  Pend.new
end
