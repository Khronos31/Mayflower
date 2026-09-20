use std::process::Command;

fn main() {
    println!("hello from rust");
    let sh = Command::new("/var/jb/bin/sh")
        .args(["-c", "echo exec_sh_c ok"])
        .output()
        .expect("sh -c");
    print!("{}", String::from_utf8_lossy(&sh.stdout));
    println!("exec_sh_c rc={}", sh.status.code().unwrap_or(-1));

    let p = Command::new("./t.sh").output().expect("start t.sh");
    print!("{}", String::from_utf8_lossy(&p.stdout));
    println!("startProcess rc={}", p.status.code().unwrap_or(-1));
    if !p.status.success() {
        eprint!("{}", String::from_utf8_lossy(&p.stderr));
        std::process::exit(1);
    }
}
