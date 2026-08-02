export default function BackgroundOrbs() {
  return (
    <>
      <div
        className="orb"
        style={{
          width: "500px",
          height: "500px",
          background: "#578ada",
          top: "-150px",
          left: "-100px",
        }}
      />
      <div
        className="orb"
        style={{
          width: "400px",
          height: "400px",
          background: "#7aa8e8",
          bottom: "-100px",
          right: "-80px",
        }}
      />
      <div
        className="orb"
        style={{
          width: "300px",
          height: "300px",
          background: "#60a5fa",
          top: "40%",
          left: "50%",
          transform: "translate(-50%, -50%)",
        }}
      />
    </>
  );
}
