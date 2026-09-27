// Captures one KWin window to a PNG. This binary is the DBus caller so
// KWin can authorize it via the desktop file's restricted-interface list.
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusUnixFileDescriptor>
#include <QImage>
#include <QVariantMap>

#include <cerrno>
#include <cstring>
#include <iostream>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc != 3) {
        std::cerr << "usage: quickxp-preview WINDOW_ID OUTPUT.png\n";
        return 2;
    }

    int fds[2] = {-1, -1};
    if (pipe(fds) != 0) {
        std::cerr << "pipe: " << std::strerror(errno) << "\n";
        return 1;
    }

    QDBusUnixFileDescriptor pipeFd(fds[1]);
    QVariantMap options;
    options.insert(QStringLiteral("include-decoration"), true);
    options.insert(QStringLiteral("include-cursor"), false);

    QDBusInterface iface(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/org/kde/KWin/ScreenShot2"),
        QStringLiteral("org.kde.KWin.ScreenShot2"),
        QDBusConnection::sessionBus());
    iface.setTimeout(8000);

    const QDBusReply<QVariantMap> reply = iface.call(
        QStringLiteral("CaptureWindow"),
        QString::fromUtf8(argv[1]),
        options,
        QVariant::fromValue(pipeFd));
    ::close(fds[1]);
    fds[1] = -1;

    if (!reply.isValid()) {
        std::cerr << reply.error().name().toStdString() << ": "
                  << reply.error().message().toStdString() << "\n";
        ::close(fds[0]);
        return 1;
    }

    const QVariantMap result = reply.value();
    const int width = result.value(QStringLiteral("width")).toInt();
    const int height = result.value(QStringLiteral("height")).toInt();
    const int stride = result.value(QStringLiteral("stride")).toInt();
    const int format = result.value(QStringLiteral("format")).toInt();
    if (width <= 0 || height <= 0 || stride <= 0 || format <= 0) {
        ::close(fds[0]);
        return 1;
    }

    QByteArray bytes;
    bytes.resize(stride * height);
    int got = 0;
    while (got < bytes.size()) {
        const ssize_t count = ::read(fds[0], bytes.data() + got, bytes.size() - got);
        if (count < 0) {
            if (errno == EINTR)
                continue;
            break;
        }
        if (count == 0)
            break;
        got += int(count);
    }
    ::close(fds[0]);
    if (got < bytes.size())
        return 1;

    QImage image(
        reinterpret_cast<const uchar *>(bytes.constData()),
        width,
        height,
        stride,
        static_cast<QImage::Format>(format));
    image = image.copy();
    constexpr int maxEdge = 480;
    if (image.width() > maxEdge || image.height() > maxEdge) {
        image = image.scaled(maxEdge, maxEdge, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    if (image.isNull() || !image.save(QString::fromUtf8(argv[2]), "PNG"))
        return 1;
    return 0;
}
