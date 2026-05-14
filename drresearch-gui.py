import sys
import os
import shutil
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QFileDialog, QProgressBar, QPlainTextEdit
from PyQt6.QtCore import QProcess, Qt, pyqtSignal

class FECaseApp(QWidget):
    process_finished = pyqtSignal()  # Signal to handle process completion

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

        # File selection section for Chip.txt
        self.file_selection_layout_chip = QHBoxLayout()
        self.file_label_chip = QLabel('Chip.txt:')
        self.file_textbox_chip = QLineEdit()
        self.browse_button_chip = QPushButton('Browse')
        self.browse_button_chip.clicked.connect(self.browse_file_chip)
        self.file_selection_layout_chip.addWidget(self.file_label_chip)
        self.file_selection_layout_chip.addWidget(self.file_textbox_chip)
        self.file_selection_layout_chip.addWidget(self.browse_button_chip)
        self.layout.addLayout(self.file_selection_layout_chip)

        # File selection section for pattern.xml
        self.file_selection_layout_pattern = QHBoxLayout()
        self.file_label_pattern = QLabel('Pattern File:')
        self.file_textbox_pattern = QLineEdit()
        self.browse_button_pattern = QPushButton('Browse')
        self.browse_button_pattern.clicked.connect(self.browse_file_pattern)
        self.file_selection_layout_pattern.addWidget(self.file_label_pattern)
        self.file_selection_layout_pattern.addWidget(self.file_textbox_pattern)
        self.file_selection_layout_pattern.addWidget(self.browse_button_pattern)
        self.layout.addLayout(self.file_selection_layout_pattern)

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

            # Automatically load Chip.txt from FE subfolder
            input_dir = os.path.dirname(file_path)
            chip_txt_path = os.path.join(input_dir, "FE", "Chip.txt")
            if os.path.exists(chip_txt_path):
                self.file_textbox_chip.setText(chip_txt_path)
                self.log_box.appendPlainText(f"Auto-loaded Chip.txt from: {chip_txt_path}")
            else:
                self.log_box.appendPlainText("No Chip.txt found in the FE subfolder.")

    def browse_file_chip(self):
        file_dialog = QFileDialog(self)
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        if file_dialog.exec():
            file_path = file_dialog.selectedFiles()[0]
            self.file_textbox_chip.setText(file_path)

    def browse_file_pattern(self):
        file_dialog = QFileDialog(self)
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        if file_dialog.exec():
            file_path = file_dialog.selectedFiles()[0]
            self.file_textbox_pattern.setText(file_path)

    def execute_all_processes(self):
        input_file = self.file_textbox_01_01.text()
        chip_file = self.file_textbox_chip.text()

        if not input_file:
            self.log_box.appendPlainText("Please select a file for 01_01.dump before executing.")
            return
        if not chip_file:
            self.log_box.appendPlainText("Please select a Chip.txt file before executing.")
            return

        # Automatically set paths for pattern.xml and upload_01_01.dump in the same folder
        input_dir = os.path.dirname(input_file)
        output_file = os.path.join(input_dir, "upload_" + os.path.basename(input_file))

        # Step 1: Execute initpattern.exe asynchronously
        self.log_box.appendPlainText("Starting initpattern.exe...")
        self.progress_bar.setValue(10)

        self.process_initpattern = QProcess(self)
        self.process_initpattern.readyReadStandardOutput.connect(self.log_output)
        self.process_initpattern.readyReadStandardError.connect(self.log_error_output)
        self.process_initpattern.finished.connect(lambda: self.move_pattern_file_and_run_dumpextract(input_file, output_file, chip_file, input_dir))
        self.process_initpattern.start('initpattern.exe', [input_file])

    def log_output(self):
        process = self.sender()
        self.log_box.appendPlainText(process.readAllStandardOutput().data().decode())

    def log_error_output(self):
        process = self.sender()
        self.log_box.appendPlainText(process.readAllStandardError().data().decode())

    def move_pattern_file_and_run_dumpextract(self, input_file, output_file, chip_file, input_dir):
        # Step 2: Move the pattern.xml to the same folder as the dump file
        pattern_file = "pattern.xml"
        target_pattern_path = os.path.join(input_dir, pattern_file)

        if os.path.exists(pattern_file):
            try:
                shutil.move(pattern_file, target_pattern_path)
                self.log_box.appendPlainText(f"Moved {pattern_file} to {target_pattern_path}")
                # Automatically update the Pattern file textbox
                self.file_textbox_pattern.setText(target_pattern_path)
            except Exception as e:
                self.log_box.appendPlainText(f"Failed to move {pattern_file}: {e}")
                return

        # Step 3: Start dumpextractrelevant.pl with the updated pattern.xml path
        self.log_box.appendPlainText("Starting dumpextractrelevant.pl...")
        self.progress_bar.setValue(50)

        self.process_dumpextract = QProcess(self)
        self.process_dumpextract.readyReadStandardOutput.connect(self.log_output)
        self.process_dumpextract.readyReadStandardError.connect(self.log_error_output)  # Capture stderr output
        self.process_dumpextract.finished.connect(self.process_completed)  # When this process finishes, mark complete
        self.process_dumpextract.start('perl', ['dumpextractrelevant.pl', input_file, output_file, target_pattern_path, chip_file])

    def process_completed(self):
        self.log_box.appendPlainText("All processes completed.")
        self.progress_bar.setValue(100)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    fe_case_app = FECaseApp()
    fe_case_app.show()
    sys.exit(app.exec())
