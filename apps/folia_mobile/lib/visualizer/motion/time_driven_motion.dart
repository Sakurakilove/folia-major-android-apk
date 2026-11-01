// A scene samples auxiliary tracks before its single repaint; implementations never own a ticker or platform channel.
abstract interface class TimeDrivenMotion {
  bool get isAnimating;
  void acceptTime(double audioTime, double nowMilliseconds);
  void advance(double nowMilliseconds);
}
