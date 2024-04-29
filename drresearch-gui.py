import sys
import os
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QFileDialog, QProgressBar, QPlainTextEdit
from PyQt6.QtCore import QProcess, Qt

class FECaseApp(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        self.setWindowTitle('LDPC Recovery')

        # Apply CSS style
        self.setStyleSheet('''
            QPushButton {
                background-color: #007ACC;
                color: white;
                border: none;
                border-radius: 5px;
                padding: 8px 16px;
            }

            QPushButton:hover {
                background-color: #005F99;
            }

            QTextEdit {
                background-color: #D9E6F5;
                color: black;
                border-radius: 5px;
                padding: 8px;
            }
        ''')
        
        self.layout = QVBoxLayout()

        # File selection section for 01_01.dump
        self.file_selection_layout_01_01 = QHBoxLayout()
        self.file_label_01_01 = QLabel('Dump File:')
        self.file_textbox_01_01 = QLineEdit()
        self.browse_button_01_01 = QPushButton('Browse')
        self.browse_button_01_01.clicked.connect(self.browse_file_01_01)
        self.file_selection_layout_01_01.addWidget(self.file_label_01_01)
        self.file_selection_layout_01_01.addWidget(self.file_textbox_01_01)
        self.file_selection_layout_01_01.addWidget(self.browse_button_01_01)
        self.layout.addLayout(self.file_selection_layout_01_01)

        # File selection section for pattern.xml
        self.file_selection_layout_pattern_xml = QHBoxLayout()
        self.file_label_pattern_xml = QLabel('Pattern File:')
        self.file_textbox_pattern_xml = QLineEdit()
        self.browse_button_pattern_xml = QPushButton('Browse')
        self.browse_button_pattern_xml.clicked.connect(self.browse_file_pattern_xml)
        self.file_selection_layout_pattern_xml.addWidget(self.file_label_pattern_xml)
        self.file_selection_layout_pattern_xml.addWidget(self.file_textbox_pattern_xml)
        self.file_selection_layout_pattern_xml.addWidget(self.browse_button_pattern_xml)
        self.layout.addLayout(self.file_selection_layout_pattern_xml)

        # File selection section for Chip.txt
        self.file_selection_layout_Chip_txt = QHBoxLayout()
        self.file_label_Chip_txt = QLabel('Chip File:')
        self.file_textbox_Chip_txt = QLineEdit()
        self.browse_button_Chip_txt = QPushButton('Browse')
        self.browse_button_Chip_txt.clicked.connect(self.browse_file_Chip_txt)
        self.file_selection_layout_Chip_txt.addWidget(self.file_label_Chip_txt)
        self.file_selection_layout_Chip_txt.addWidget(self.file_textbox_Chip_txt)
        self.file_selection_layout_Chip_txt.addWidget(self.browse_button_Chip_txt)
        self.layout.addLayout(self.file_selection_layout_Chip_txt)

        # Execute button
        self.btn_execute_all = QPushButton('Start')
        self.btn_execute_all.clicked.connect(self.execute_all_processes)
        self.layout.addWidget(self.btn_execute_all)

        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        self.layout.addWidget(self.progress_bar)

        # Log box
        self.log_box = QPlainTextEdit()
        self.log_box.setReadOnly(True)
        self.layout.addWidget(self.log_box)

        self.setLayout(self.layout)

    def browse_file_01_01(self):
        file_dialog = QFileDialog(self)
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        if file_dialog.exec():
            file_path = file_dialog.selectedFiles()[0]
            self.file_textbox_01_01.setText(file_path)

            # Auto-load pattern.xml and Chip.txt paths
            dir_path = os.path.dirname(file_path)
            self.file_textbox_pattern_xml.setText(os.path.join(dir_path, "pattern.xml"))
            self.file_textbox_Chip_txt.setText(os.path.join(dir_path, "Chip.txt"))

    def browse_file_pattern_xml(self):
        file_dialog = QFileDialog(self)
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        if file_dialog.exec():
            file_path = file_dialog.selectedFiles()[0]
            self.file_textbox_pattern_xml.setText(file_path)

    def browse_file_Chip_txt(self):
        file_dialog = QFileDialog(self)
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        if file_dialog.exec():
            file_path = file_dialog.selectedFiles()[0]
            self.file_textbox_Chip_txt.setText(file_path)

    def execute_all_processes(self):
        input_file = self.file_textbox_01_01.text()
        if not input_file:
            self.log_box.appendPlainText("Please select a file for 01_01.dump before executing.")
            return

        output_file = "upload_" + os.path.basename(input_file)
        xml_file = self.file_textbox_pattern_xml.text()
        chip_file = self.file_textbox_Chip_txt.text()

        # Execute initpattern.exe
        process_initpattern = QProcess()
        process_initpattern.readyReadStandardOutput.connect(lambda: self.log_box.appendPlainText(process_initpattern.readAllStandardOutput().data().decode()))
        process_initpattern.start('initpattern.exe', [input_file])
        process_initpattern.waitForFinished()

        # Execute dumpextractrelevant.pl
        input_file_dumpextract = input_file
        process_dumpextract = QProcess()
        process_dumpextract.readyReadStandardOutput.connect(lambda: self.log_box.appendPlainText(process_dumpextract.readAllStandardOutput().data().decode()))
        process_dumpextract.start('perl', ['dumpextractrelevant.pl', input_file_dumpextract, output_file, xml_file, chip_file])
        process_dumpextract.waitForFinished()

        # Execute dumpdecoder.py
        input_file_dumpdecoder = input_file
        corrected_file = "corrected" + os.path.splitext(input_file)[1]  # Assuming the corrected file has the same extension as input
        process_dumpdecoder = QProcess()
        process_dumpdecoder.readyReadStandardOutput.connect(lambda: self.log_box.appendPlainText(process_dumpdecoder.readAllStandardOutput().data().decode()))
        process_dumpdecoder.start('python3', ['dumpdecoder.py', input_file_dumpdecoder, "hmatrix_n36544_k32768_m3776.h", "4k.case", corrected_file])
        process_dumpdecoder.waitForFinished()

        self.log_box.appendPlainText("All processes completed.")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    fe_case_app = FECaseApp()
    fe_case_app.show()
    sys.exit(app.exec())
