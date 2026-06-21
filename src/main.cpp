#include <QApplication>
#include <QMainWindow>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QMessageBox>

class HeidiSQLApp : public QApplication {
public:
    explicit HeidiSQLApp(int &argc, char **argv) : QApplication(argc, argv) {
        // Initialize the main window
        auto *window = new QMainWindow(this);
        window->setWindowTitle("HeidiSQL 12.19.0.7314");

        auto *layout = new QVBoxLayout();

        auto *label = new QLabel("HeidiSQL v12.19.0.7314 is now available!");
        label->setAlignment(Qt::AlignCenter);
        layout->addWidget(label);

        auto *updateBtn = new QPushButton("Check for Updates");
        connect(updateBtn, &QPushButton::clicked, this, []() {
            QMessageBox::information(nullptr, "Update Info",
                                    "New version: 12.19.0.7314\n"
                                    "Download: https://github.com/HeidiSQL/HeidiSQL/releases/download/v12.19/HeidiSQL_12.19.0.7314_Setup.exe");
        });
        layout->addWidget(updateBtn);

        auto *statusLabel = new QLabel("Ready");
        statusLabel->setStyleSheet("color: green;");
        layout->addWidget(statusLabel);

        window->setCentralWidget(new QWidget(window));
        window->centralWidget()->setLayout(layout);
        window->show();
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    QCoreApplication::setAttribute(Qt::AA_UseSoftwareRendering);

    auto app = new HeidiSQLApp(argc, argv);

    // Simulate application startup
    QTimer::singleShot(1000, app, []() {
        app->quit();
    });

    return app->exec();
}